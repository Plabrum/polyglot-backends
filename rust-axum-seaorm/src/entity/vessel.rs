//! SeaORM entity for the shared `vessels` table — the "table defined in code".
//!
//! Mirrors db/init/001_schema.sql. We never run migrations from this service;
//! the entity just maps the existing columns. `id` is an identity column and
//! `created_at` is DB-filled, so both are left `NotSet` on insert and the
//! Postgres `RETURNING` clause repopulates them.

use sea_orm::entity::prelude::*;

#[derive(Clone, Debug, PartialEq, DeriveEntityModel)]
#[sea_orm(table_name = "vessels")]
pub struct Model {
    #[sea_orm(primary_key)]
    pub id: i64,
    pub name: String,
    pub length_m: f64,
    pub created_at: DateTimeWithTimeZone,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {}

impl ActiveModelBehavior for ActiveModel {}
