(* OCaml backend: Dream (web framework) + Caqti (typed Postgres client).
   Dream's built-in [sql_pool] middleware manages a Caqti connection pool;
   [Dream.sql] checks out a connection for the duration of a handler.
   Exposes GET /health, GET /vessels, POST /vessels on the shared table.

   Wire types carry [@@deriving yojson], so the JSON encoder/decoder are
   generated from the type definition instead of written by hand. *)

let database_url =
  match Sys.getenv_opt "DATABASE_URL" with
  | Some url -> url
  | None -> "postgresql://app:app@localhost:5434/app"

(* --- wire types (one definition drives both directions) --- *)

type vessel = { id : int; name : string; length_m : float; created_at : string }
[@@deriving yojson]

(* Request body for POST /vessels. [@default] makes length_m optional. *)
type vessel_in = { name : string; length_m : float [@default 0.0] }
[@@deriving yojson]

(* --- queries. created_at is cast to text so we don't need a ptime decoder. --- *)
module Q = struct
  open Caqti_request.Infix
  open Caqti_type.Std

  let list_vessels =
    (unit ->* t4 int string float string)
      "SELECT id, name, length_m, created_at::text FROM vessels ORDER BY id"

  let create_vessel =
    (t2 string float ->! t4 int string float string)
      "INSERT INTO vessels (name, length_m) VALUES (?, ?) RETURNING id, name, \
       length_m, created_at::text"
end

(* Caqti returns rows as tuples; map onto the record once, here. *)
let vessel_of_row (id, name, length_m, created_at) =
  { id; name; length_m; created_at }

let respond_json json = Dream.json (Yojson.Safe.to_string json)

let error_json ?(status = `Internal_Server_Error) msg =
  Dream.json ~status (Yojson.Safe.to_string (`Assoc [ ("error", `String msg) ]))

let list_vessels request =
  let%lwt result =
    Dream.sql request (fun (module Db : Caqti_lwt.CONNECTION) ->
        Db.collect_list Q.list_vessels ())
  in
  match result with
  | Ok rows ->
      respond_json
        (`List (List.map (fun r -> vessel_to_yojson (vessel_of_row r)) rows))
  | Error e -> error_json (Caqti_error.show e)

let insert_vessel request (input : vessel_in) =
  let%lwt result =
    Dream.sql request (fun (module Db : Caqti_lwt.CONNECTION) ->
        Db.find Q.create_vessel (input.name, input.length_m))
  in
  match result with
  | Ok row -> respond_json (vessel_to_yojson (vessel_of_row row))
  | Error e -> error_json (Caqti_error.show e)

let create_vessel request =
  let%lwt body = Dream.body request in
  match vessel_in_of_yojson (Yojson.Safe.from_string body) with
  | Error msg -> error_json ~status:`Bad_Request msg
  | Ok input -> insert_vessel request input

let () =
  Dream.run ~interface:"0.0.0.0" ~port:8003
  @@ Dream.logger
  @@ Dream.sql_pool database_url
  @@ Dream.router
       [
         Dream.get "/health" (fun _ ->
             Dream.json {|{"status": "ok", "service": "ocaml-dream"}|});
         Dream.get "/vessels" list_vessels;
         Dream.post "/vessels" create_vessel;
       ]
