import { usarMocks } from "../config/environment";
import { catalogosMock } from "../mocks/mockData";
import { mockError, mockResult } from "../mocks/mockUtils";
import { apiGet } from "./api";

export async function listarCatalogo(nombre) {
  if (!usarMocks()) return apiGet(`/api/catalogos/${nombre}`);
  const values = catalogosMock[nombre];
  if (!values) mockError("Catálogo no encontrado", 404);
  return mockResult(values.map((codigo, index) => ({ id: index + 1, codigo, nombre: codigo.replaceAll("_", " ") })));
}
