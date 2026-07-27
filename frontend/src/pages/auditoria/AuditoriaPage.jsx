import {Braces, Search} from "lucide-react";
import {useState} from "react";
import Badge from "../../components/common/Badge";
import Modal from "../../components/common/Modal";
import PageHeader from "../../components/common/PageHeader";
import {EmptyState, ErrorState, LoadingBlock} from "../../components/common/StateViews";
import useAsyncData from "../../hooks/useAsyncData";
import {consultarAuditoria} from "../../services/reporteService";
import {formatDateTime} from "../../utils/formatters";

export default function AuditoriaPage() {
    const [filters, setFilters] = useState({esquema: "", tabla: "", operacion: "", limite: 100});
    const [selected, setSelected] = useState(null);
    const {
        data,
        loading,
        error,
        reload
    } = useAsyncData(() => consultarAuditoria(filters), [filters.esquema, filters.tabla, filters.operacion, filters.limite]);
    return <><PageHeader title="Auditoría" description="Trazabilidad de cambios registrada por PostgreSQL y FastAPI."/>
        <section className="toolbar card"><label className="search-control"><Search size={17}/><input
            value={filters.esquema} onChange={(e) => setFilters({...filters, esquema: e.target.value})}
            placeholder="Esquema"/></label><input className="filter-select" value={filters.tabla}
                                                  onChange={(e) => setFilters({...filters, tabla: e.target.value})}
                                                  placeholder="Tabla"/><select className="filter-select"
                                                                               value={filters.operacion}
                                                                               onChange={(e) => setFilters({
                                                                                   ...filters,
                                                                                   operacion: e.target.value
                                                                               })}>
            <option value="">Todas las operaciones</option>
            <option value="INSERT">INSERT</option>
            <option value="UPDATE">UPDATE</option>
            <option value="DELETE">DELETE</option>
        </select><select className="filter-select" value={filters.limite}
                         onChange={(e) => setFilters({...filters, limite: Number(e.target.value)})}>
            <option value="50">50 registros</option>
            <option value="100">100 registros</option>
            <option value="250">250 registros</option>
            <option value="500">500 registros</option>
        </select></section>
        {loading ? <LoadingBlock/> : error ? <ErrorState message={error} onRetry={reload}/> : !data?.datos.length ?
            <EmptyState title="No hay eventos de auditoría"/> : <div className="table-wrap card">
                <table>
                    <thead>
                    <tr>
                        <th>Fecha</th>
                        <th>Esquema / tabla</th>
                        <th>Operación</th>
                        <th>Registro</th>
                        <th>Columnas</th>
                        <th>Usuario</th>
                        <th>IP</th>
                        <th>Request ID</th>
                        <th/>
                    </tr>
                    </thead>
                    <tbody>{data.datos.map((item, index) => <tr
                        key={`${item.id_solicitud || item.request_id}-${index}`}>
                        <td>{formatDateTime(item.fecha_evento || item.fecha)}</td>
                        <td><strong>{item.esquema}</strong><small>{item.tabla}</small></td>
                        <td><Badge value={item.operacion}
                                   tone={item.operacion === "DELETE" ? "danger" : item.operacion === "INSERT" ? "success" : "info"}/>
                        </td>
                        <td>
                            {(() => {
                                const reg = item.identificador_registro || item.identificador;
                                if (!reg) return "—";
                                try {
                                    // Si es un JSON en texto como {"id_usuario": 1}, intentamos extraer su valor
                                    const parsed = JSON.parse(reg);
                                    const valores = Object.values(parsed);
                                    return valores.length ? `#${valores.join("-")}` : reg;
                                } catch {
                                    // Si es un texto normal, lo dejamos tal cual
                                    return reg;
                                }
                            })()}
                        </td>
                        <td>{Array.isArray(item.columnas_modificadas) ? item.columnas_modificadas.join(", ") : item.columnas_modificadas || "—"}</td>
                        <td>{item.usuario_aplicacion_nombre || item.usuario || item.usuario_aplicacion || "—"}</td>
                        <td className="mono">{item.ip_cliente || item.direccion_ip || "—"}</td>
                        <td className="mono">{item.id_solicitud || item.request_id || "—"}</td>
                        <td>
                            <button className="icon-button" onClick={() => setSelected(item)} aria-label="Ver JSON">
                                <Braces size={16}/></button>
                        </td>
                    </tr>)}</tbody>
                </table>
            </div>}<Modal open={Boolean(selected)} onClose={() => setSelected(null)} title="Detalle de auditoría" wide>
            <div className="audit-json-grid">
                <section><p className="eyebrow">DATOS ANTERIORES</p>
                    <pre>{JSON.stringify(selected?.datos_anteriores ?? null, null, 2)}</pre>
                </section>
                <section><p className="eyebrow">DATOS NUEVOS</p>
                    <pre>{JSON.stringify(selected?.datos_nuevos ?? null, null, 2)}</pre>
                </section>
            </div>
        </Modal></>;
}
