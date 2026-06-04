package schema

import (
	"time"

	"entgo.io/ent"
	"entgo.io/ent/schema/field"
)

// Vessel maps onto the shared `vessels` table. The id column is
// GENERATED ALWAYS AS IDENTITY in Postgres, so ent never sets it.
type Vessel struct {
	ent.Schema
}

func (Vessel) Fields() []ent.Field {
	return []ent.Field{
		field.String("name"),
		field.Float("length_m").Default(0),
		field.Time("created_at").Default(time.Now),
	}
}
