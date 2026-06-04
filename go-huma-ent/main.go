// Go backend: huma (typed HTTP + OpenAPI) over ent (typed Postgres client).
// Exposes GET /health, GET /vessels, POST /vessels on the shared table.
// OpenAPI docs are served at /docs.
package main

import (
	"context"
	"database/sql"
	"log"
	"net/http"
	"os"
	"time"

	"entgo.io/ent/dialect"
	entsql "entgo.io/ent/dialect/sql"
	"github.com/danielgtaylor/huma/v2"
	"github.com/danielgtaylor/huma/v2/adapters/humago"
	_ "github.com/jackc/pgx/v5/stdlib"

	"polyglot/ent"
	"polyglot/ent/vessel"
)

type VesselOut struct {
	ID        int       `json:"id"`
	Name      string    `json:"name"`
	LengthM   float64   `json:"length_m"`
	CreatedAt time.Time `json:"created_at"`
}

func toOut(v *ent.Vessel) VesselOut {
	return VesselOut{ID: v.ID, Name: v.Name, LengthM: v.LengthM, CreatedAt: v.CreatedAt}
}

type HealthResponse struct {
	Body struct {
		Status  string `json:"status"`
		Service string `json:"service"`
	}
}

type ListResponse struct {
	Body []VesselOut
}

type VesselResponse struct {
	Body VesselOut
}

type CreateRequest struct {
	Body struct {
		Name    string  `json:"name" minLength:"1"`
		LengthM float64 `json:"length_m" default:"0"`
	}
}

func main() {
	dsn := os.Getenv("DATABASE_URL")
	if dsn == "" {
		dsn = "postgres://app:app@localhost:5434/app?sslmode=disable"
	}

	db, err := sql.Open("pgx", dsn)
	if err != nil {
		log.Fatalf("open db: %v", err)
	}
	client := ent.NewClient(ent.Driver(entsql.OpenDB(dialect.Postgres, db)))
	defer client.Close()

	mux := http.NewServeMux()
	api := humago.New(mux, huma.DefaultConfig("Vessels API", "1.0.0"))

	huma.Get(api, "/health", func(ctx context.Context, _ *struct{}) (*HealthResponse, error) {
		resp := &HealthResponse{}
		resp.Body.Status = "ok"
		resp.Body.Service = "go-huma-ent"
		return resp, nil
	})

	huma.Get(api, "/vessels", func(ctx context.Context, _ *struct{}) (*ListResponse, error) {
		rows, err := client.Vessel.Query().Order(ent.Asc(vessel.FieldID)).All(ctx)
		if err != nil {
			return nil, huma.Error500InternalServerError("query failed", err)
		}
		out := make([]VesselOut, len(rows))
		for i, v := range rows {
			out[i] = toOut(v)
		}
		return &ListResponse{Body: out}, nil
	})

	huma.Post(api, "/vessels", func(ctx context.Context, in *CreateRequest) (*VesselResponse, error) {
		v, err := client.Vessel.Create().
			SetName(in.Body.Name).
			SetLengthM(in.Body.LengthM).
			Save(ctx)
		if err != nil {
			return nil, huma.Error500InternalServerError("insert failed", err)
		}
		return &VesselResponse{Body: toOut(v)}, nil
	})

	log.Println("listening on :8002 (OpenAPI docs at /docs)")
	if err := http.ListenAndServe(":8002", mux); err != nil {
		log.Fatal(err)
	}
}
