//! Rust backend: Axum (async HTTP) over SeaORM (typed Postgres) with utoipa
//! for the OpenAPI spec. Exposes GET /health, GET /vessels, POST /vessels on
//! the shared `vessels` table. OpenAPI docs are served at /docs.
//!
//! Like the Litestar reference, the DB-layer model (the `vessel` SeaORM entity)
//! is kept separate from the wire types (`VesselIn` / `VesselOut`), with a
//! small `to_out` converter between them.

mod entity;

use std::env;

use axum::{
    extract::State,
    routing::get,
    Json, Router,
};
use chrono::{DateTime, FixedOffset};
use sea_orm::{
    ActiveModelTrait, Database, DatabaseConnection, EntityTrait, QueryOrder, Set,
};
use serde::{Deserialize, Serialize};
use tokio::net::TcpListener;
use utoipa::{OpenApi, ToSchema};
use utoipa_swagger_ui::SwaggerUi;

use entity::vessel;

// --- wire types (what crosses the HTTP boundary) ---

#[derive(Debug, Deserialize, ToSchema)]
struct VesselIn {
    name: String,
    #[serde(default)]
    length_m: f64,
}

#[derive(Debug, Serialize, ToSchema)]
struct VesselOut {
    id: i64,
    name: String,
    length_m: f64,
    created_at: DateTime<FixedOffset>,
}

fn to_out(v: vessel::Model) -> VesselOut {
    VesselOut {
        id: v.id,
        name: v.name,
        length_m: v.length_m,
        created_at: v.created_at,
    }
}

#[derive(Debug, Serialize, ToSchema)]
struct HealthResponse {
    status: String,
    service: String,
}

// --- handlers ---

#[utoipa::path(get, path = "/health", responses((status = 200, body = HealthResponse)))]
async fn health() -> Json<HealthResponse> {
    Json(HealthResponse {
        status: "ok".to_string(),
        service: "rust-axum-seaorm".to_string(),
    })
}

#[utoipa::path(get, path = "/vessels", responses((status = 200, body = [VesselOut])))]
async fn list_vessels(State(db): State<DatabaseConnection>) -> Json<Vec<VesselOut>> {
    let rows = vessel::Entity::find()
        .order_by_asc(vessel::Column::Id)
        .all(&db)
        .await
        .expect("query failed");
    Json(rows.into_iter().map(to_out).collect())
}

#[utoipa::path(post, path = "/vessels", request_body = VesselIn, responses((status = 200, body = VesselOut)))]
async fn create_vessel(
    State(db): State<DatabaseConnection>,
    Json(data): Json<VesselIn>,
) -> Json<VesselOut> {
    let v = vessel::ActiveModel {
        name: Set(data.name),
        length_m: Set(data.length_m),
        ..Default::default()
    }
    .insert(&db)
    .await
    .expect("insert failed");
    Json(to_out(v))
}

#[derive(OpenApi)]
#[openapi(
    paths(health, list_vessels, create_vessel),
    components(schemas(VesselIn, VesselOut, HealthResponse))
)]
struct ApiDoc;

#[tokio::main]
async fn main() {
    let dsn = env::var("DATABASE_URL")
        .unwrap_or_else(|_| "postgres://app:app@localhost:5434/app".to_string());

    let db = Database::connect(&dsn)
        .await
        .expect("failed to connect to database");

    let app = Router::new()
        .route("/health", get(health))
        .route("/vessels", get(list_vessels).post(create_vessel))
        .merge(SwaggerUi::new("/docs").url("/openapi.json", ApiDoc::openapi()))
        .with_state(db);

    let listener = TcpListener::bind("0.0.0.0:8005")
        .await
        .expect("failed to bind :8005");
    println!("listening on :8005 (OpenAPI docs at /docs)");
    axum::serve(listener, app).await.expect("server error");
}
