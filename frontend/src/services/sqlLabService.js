import {
  apiGet,
  apiPost,
} from "./api";

export async function ejecutarScriptSql(script) {
  return apiPost(
    "/api/sql-lab/ejecutar",
    { script },
  );
}

export async function listarObjetosSql() {
  return apiGet("/api/sql-lab/objetos");
}
