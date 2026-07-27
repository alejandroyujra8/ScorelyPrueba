import {
  AlertCircle,
  BookOpen,
  CheckCircle2,
  Clock3,
  Copy,
  Database,
  Eraser,
  GitBranch,
  Loader2,
  Play,
  Rows3,
  Search,
  ShieldCheck,
  Table2,
  Zap,
} from "lucide-react";

import {
  useMemo,
  useRef,
  useState,
} from "react";

import {
  usarMocks,
} from "../../config/environment";

import useAsyncData from "../../hooks/useAsyncData";

import {
  ejecutarScriptSql,
  listarObjetosSql,
} from "../../services/sqlLabService";

import {
  DEFAULT_SQL,
  SQL_CATEGORIES,
  SQL_EXAMPLES,
} from "./sqlExamples";

import "../../styles/sql-lab.css";


function convertirValorTexto(valor) {
  if (valor === null) {
    return "NULL";
  }

  if (typeof valor === "object") {
    return JSON.stringify(
      valor,
      null,
      2,
    );
  }

  if (typeof valor === "boolean") {
    return valor
      ? "TRUE"
      : "FALSE";
  }

  return String(valor);
}


function CeldaResultado({
  valor,
}) {
  if (valor === null) {
    return (
      <span className="sql-lab-null">
        NULL
      </span>
    );
  }

  if (typeof valor === "boolean") {
    return (
      <span
        className={
          valor
            ? "sql-lab-boolean sql-lab-boolean--true"
            : "sql-lab-boolean sql-lab-boolean--false"
        }
      >
        {valor ? "TRUE" : "FALSE"}
      </span>
    );
  }

  if (typeof valor === "object") {
    return (
      <pre className="sql-lab-json">
        {convertirValorTexto(valor)}
      </pre>
    );
  }

  return convertirValorTexto(valor);
}


function ResultadoTabla({
  resultado,
}) {
  const tieneColumnas =
    Array.isArray(resultado.columnas) &&
    resultado.columnas.length > 0;

  const tieneFilas =
    Array.isArray(resultado.filas) &&
    resultado.filas.length > 0;

  return (
    <article className="sql-lab-result-card">
      <header className="sql-lab-result-header">
        <div className="sql-lab-result-title">
          <span className="sql-lab-result-number">
            {resultado.indice}
          </span>

          <div>
            <strong>
              {resultado.comando ||
                "SQL"}
            </strong>

            <p>
              {resultado.mensaje ||
                "Comando ejecutado"}
            </p>
          </div>
        </div>

        <div className="sql-lab-result-count">
          <Rows3 size={15} />

          <span>
            {resultado.cantidad_filas ||
              0} filas
          </span>
        </div>
      </header>

      {resultado.filas_truncadas && (
        <div className="sql-lab-result-warning">
          El resultado fue limitado a las
          primeras 500 filas.
        </div>
      )}

      {!tieneColumnas && (
        <div className="sql-lab-command-result">
          <CheckCircle2 size={20} />

          <span>
            La instrucción se ejecutó
            correctamente y no devolvió una
            tabla.
          </span>
        </div>
      )}

      {tieneColumnas && !tieneFilas && (
        <div className="sql-lab-empty-result">
          <Table2 size={23} />

          <span>
            La consulta no devolvió registros.
          </span>
        </div>
      )}

      {tieneColumnas && tieneFilas && (
        <div className="sql-lab-table-scroll">
          <table className="sql-lab-table">
            <thead>
              <tr>
                <th className="sql-lab-row-index">
                  #
                </th>

                {resultado.columnas.map(
                  (columna) => (
                    <th key={columna}>
                      {columna}
                    </th>
                  ),
                )}
              </tr>
            </thead>

            <tbody>
              {resultado.filas.map(
                (fila, indiceFila) => (
                  <tr
                    key={`${resultado.indice}-${indiceFila}`}
                  >
                    <td className="sql-lab-row-index">
                      {indiceFila + 1}
                    </td>

                    {resultado.columnas.map(
                      (columna) => (
                        <td
                          key={`${indiceFila}-${columna}`}
                        >
                          <CeldaResultado
                            valor={
                              fila[columna]
                            }
                          />
                        </td>
                      ),
                    )}
                  </tr>
                ),
              )}
            </tbody>
          </table>
        </div>
      )}
    </article>
  );
}


function copiarConRespaldo(
  texto,
) {
  if (
    navigator.clipboard &&
    window.isSecureContext
  ) {
    return navigator.clipboard.writeText(
      texto,
    );
  }

  const elemento =
    document.createElement("textarea");

  elemento.value = texto;
  elemento.style.position = "fixed";
  elemento.style.opacity = "0";

  document.body.appendChild(
    elemento,
  );

  elemento.focus();
  elemento.select();

  document.execCommand("copy");

  document.body.removeChild(
    elemento,
  );

  return Promise.resolve();
}


export default function SqlLabPage() {
  const editorRef = useRef(null);
  const numerosRef = useRef(null);

  const modoMocks = usarMocks();

  const [vistaLateral, setVistaLateral] =
    useState("ejemplos");

  const {
    data: objetosSql,
    loading: cargandoObjetos,
    error: errorObjetos,
  } = useAsyncData(
    () => listarObjetosSql(),
    [],
    !modoMocks,
  );

  const [script, setScript] =
    useState(DEFAULT_SQL);

  const [
    categoriaSeleccionada,
    setCategoriaSeleccionada,
  ] = useState("todos");

  const [
    busquedaEjemplo,
    setBusquedaEjemplo,
  ] = useState("");

  const [
    ejemploSeleccionado,
    setEjemploSeleccionado,
  ] = useState(
    SQL_EXAMPLES[0].id,
  );

  const [ejecutando, setEjecutando] =
    useState(false);

  const [respuesta, setRespuesta] =
    useState(null);

  const [error, setError] =
    useState("");

  const [copiado, setCopiado] =
    useState(false);

  const lineas = useMemo(
    () =>
      Array.from(
        {
          length: Math.max(
            script.split("\n").length,
            1,
          ),
        },
        (_, indice) => indice + 1,
      ),
    [script],
  );

  const ejemplosFiltrados =
    useMemo(() => {
      const texto =
        busquedaEjemplo
          .trim()
          .toLowerCase();

      return SQL_EXAMPLES.filter(
        (ejemplo) => {
          const coincideCategoria =
            categoriaSeleccionada ===
              "todos" ||
            ejemplo.categoria ===
              categoriaSeleccionada;

          const contenido =
            `${ejemplo.titulo} ${ejemplo.descripcion}`
              .toLowerCase();

          const coincideBusqueda =
            !texto ||
            contenido.includes(texto);

          return (
            coincideCategoria &&
            coincideBusqueda
          );
        },
      );
    }, [
      categoriaSeleccionada,
      busquedaEjemplo,
    ]);

  const totalFilas = useMemo(
    () =>
      respuesta?.resultados?.reduce(
        (total, resultado) =>
          total +
          Number(
            resultado.cantidad_filas ||
              0,
          ),
        0,
      ) || 0,
    [respuesta],
  );

  function seleccionarEjemplo(
    ejemplo,
  ) {
    setEjemploSeleccionado(
      ejemplo.id,
    );

    setScript(
      ejemplo.sql,
    );

    setRespuesta(null);
    setError("");

    window.setTimeout(() => {
      editorRef.current?.focus();
    }, 0);
  }

  function seleccionarObjeto(objeto) {
    setEjemploSeleccionado("");
    setScript(objeto.sql_inspeccion);
    setRespuesta(null);
    setError("");

    window.setTimeout(() => {
      editorRef.current?.focus();
    }, 0);
  }

  function limpiarEditor() {
    setScript("");
    setRespuesta(null);
    setError("");
    setEjemploSeleccionado("");
    editorRef.current?.focus();
  }

  async function copiarScript() {
    try {
      await copiarConRespaldo(script);

      setCopiado(true);

      window.setTimeout(() => {
        setCopiado(false);
      }, 1600);
    } catch {
      setError(
        "No se pudo copiar el script.",
      );
    }
  }

  async function ejecutarScript() {
    const scriptLimpio =
      script.trim();

    if (!scriptLimpio) {
      setError(
        "Escribe una instrucción SQL antes de ejecutar.",
      );

      editorRef.current?.focus();
      return;
    }

    if (modoMocks) {
      setError(
        "El Laboratorio SQL requiere conexión real con FastAPI. Configura VITE_USE_MOCKS=false.",
      );

      return;
    }

    setEjecutando(true);
    setRespuesta(null);
    setError("");

    try {
      const datos =
        await ejecutarScriptSql(
          scriptLimpio,
        );

      setRespuesta(datos);
    } catch (errorEjecucion) {
      setError(
        errorEjecucion?.message ||
          "No se pudo ejecutar el script SQL.",
      );
    } finally {
      setEjecutando(false);
    }
  }

  function sincronizarScroll(
    evento,
  ) {
    if (numerosRef.current) {
      numerosRef.current.scrollTop =
        evento.currentTarget.scrollTop;
    }
  }

  function controlarTeclado(
    evento,
  ) {
    const ejecutarConTeclado =
      (evento.ctrlKey ||
        evento.metaKey) &&
      evento.key === "Enter";

    if (ejecutarConTeclado) {
      evento.preventDefault();

      ejecutarScript();
    }

    if (
      evento.key === "Tab"
    ) {
      evento.preventDefault();

      const inicio =
        evento.currentTarget
          .selectionStart;

      const fin =
        evento.currentTarget
          .selectionEnd;

      const nuevoScript =
        `${script.substring(
          0,
          inicio,
        )}    ${script.substring(fin)}`;

      setScript(nuevoScript);

      window.setTimeout(() => {
        evento.currentTarget
          .setSelectionRange(
            inicio + 4,
            inicio + 4,
          );
      }, 0);
    }
  }

  return (
    <div className="sql-lab-page">
      <header className="sql-lab-page-header">
        <div>
          <div className="sql-lab-eyebrow">
            <Database size={17} />

            <span>
              Base de Datos II
            </span>
          </div>

          <h1>
            Laboratorio SQL
          </h1>

          <p>
            Ejecuta consultas, funciones,
            procedimientos, triggers y
            cursores en PostgreSQL.
          </p>
        </div>

        <div className="sql-lab-mode-badge">
          <ShieldCheck size={18} />

          <div>
            <strong>
              Modo simulación
            </strong>

            <span>
              Rollback automático
            </span>
          </div>
        </div>
      </header>

      <div className="sql-lab-safety-notice">
        <ShieldCheck size={20} />

        <div>
          <strong>
            Entorno controlado
          </strong>

          <p>
            Los cambios realizados mediante
            DDL o DML se revierten al terminar
            la ejecución. Las instrucciones
            administrativas peligrosas están
            bloqueadas.
          </p>
        </div>
      </div>

      {modoMocks && (
        <div className="sql-lab-mock-warning">
          <AlertCircle size={20} />

          <div>
            <strong>
              El frontend utiliza datos
              simulados
            </strong>

            <p>
              Cambia la variable
              VITE_USE_MOCKS a false para
              utilizar el Laboratorio SQL.
            </p>
          </div>
        </div>
      )}

      <div className="sql-lab-workspace">
        <aside className="sql-lab-examples">
          <div className="sql-lab-panel-heading">
            <BookOpen size={19} />

            <div>
              <strong>Atajos SQL</strong>
              <span>Objetos reales del sistema</span>
            </div>
          </div>

          <div className="sql-lab-sidebar-tabs">
            <button
              type="button"
              className={vistaLateral === "ejemplos" ? "is-active" : ""}
              onClick={() => setVistaLateral("ejemplos")}
            >
              <BookOpen size={15} />
              Ejemplos
            </button>
            <button
              type="button"
              className={vistaLateral === "triggers" ? "is-active" : ""}
              onClick={() => setVistaLateral("triggers")}
              disabled={modoMocks}
            >
              <Zap size={15} />
              Triggers ({objetosSql?.triggers?.length || 0})
            </button>
            <button
              type="button"
              className={vistaLateral === "cursores" ? "is-active" : ""}
              onClick={() => setVistaLateral("cursores")}
              disabled={modoMocks}
            >
              <GitBranch size={15} />
              Cursores ({objetosSql?.cursores?.length || 0})
            </button>
          </div>

          {vistaLateral === "ejemplos" && (
            <>
              <label className="sql-lab-search">
                <Search size={17} />

                <input
                  type="search"
                  value={busquedaEjemplo}
                  onChange={(evento) =>
                    setBusquedaEjemplo(evento.target.value)
                  }
                  placeholder="Buscar ejemplo"
                />
              </label>

              <div className="sql-lab-categories">
                <button
                  type="button"
                  className={
                    categoriaSeleccionada === "todos"
                      ? "is-active"
                      : ""
                  }
                  onClick={() => setCategoriaSeleccionada("todos")}
                >
                  Todos
                </button>

                {SQL_CATEGORIES.map((categoria) => (
                  <button
                    type="button"
                    key={categoria.id}
                    className={
                      categoriaSeleccionada === categoria.id
                        ? "is-active"
                        : ""
                    }
                    onClick={() => setCategoriaSeleccionada(categoria.id)}
                  >
                    {categoria.label}
                  </button>
                ))}
              </div>

              <div className="sql-lab-example-list">
                {ejemplosFiltrados.map((ejemplo) => (
                  <button
                    type="button"
                    key={ejemplo.id}
                    className={
                      ejemploSeleccionado === ejemplo.id
                        ? "sql-lab-example is-active"
                        : "sql-lab-example"
                    }
                    onClick={() => seleccionarEjemplo(ejemplo)}
                  >
                    <strong>{ejemplo.titulo}</strong>
                    <span>{ejemplo.descripcion}</span>
                  </button>
                ))}

                {ejemplosFiltrados.length === 0 && (
                  <div className="sql-lab-no-examples">
                    No se encontraron ejemplos.
                  </div>
                )}
              </div>
            </>
          )}

          {vistaLateral !== "ejemplos" && cargandoObjetos && (
            <div className="sql-lab-sidebar-status">
              <Loader2 className="sql-lab-spinner" size={20} />
              Cargando objetos de PostgreSQL...
            </div>
          )}

          {vistaLateral !== "ejemplos" && errorObjetos && (
            <div className="sql-lab-sidebar-error">
              <AlertCircle size={18} />
              {errorObjetos}
            </div>
          )}

          {vistaLateral === "triggers" && !cargandoObjetos && (
            <div className="sql-lab-object-list">
              {(objetosSql?.triggers || []).map((trigger) => (
                <button
                  type="button"
                  key={`${trigger.esquema}.${trigger.tabla}.${trigger.nombre}`}
                  className="sql-lab-object-card"
                  onClick={() => seleccionarObjeto(trigger)}
                >
                  <span className="sql-lab-object-kind">
                    <Zap size={14} /> TRIGGER
                  </span>
                  <strong>{trigger.nombre}</strong>
                  <small>{trigger.esquema}.{trigger.tabla}</small>
                  <em>{trigger.funcion_esquema}.{trigger.funcion_nombre}()</em>
                </button>
              ))}
              {!objetosSql?.triggers?.length && !errorObjetos && (
                <div className="sql-lab-no-examples">
                  No se encontraron triggers del proyecto.
                </div>
              )}
            </div>
          )}

          {vistaLateral === "cursores" && !cargandoObjetos && (
            <div className="sql-lab-object-list">
              {(objetosSql?.cursores || []).map((cursor) => (
                <button
                  type="button"
                  key={`${cursor.esquema}.${cursor.rutina}.${cursor.argumentos}`}
                  className="sql-lab-object-card"
                  onClick={() => seleccionarObjeto(cursor)}
                >
                  <span className="sql-lab-object-kind">
                    <GitBranch size={14} /> {cursor.tipo_rutina}
                  </span>
                  <strong>{cursor.rutina}</strong>
                  <small>{cursor.esquema}</small>
                  <em>
                    {cursor.cursores?.length
                      ? cursor.cursores.join(", ")
                      : "Cursor declarado en la rutina"}
                  </em>
                </button>
              ))}
              {!objetosSql?.cursores?.length && !errorObjetos && (
                <div className="sql-lab-no-examples">
                  No se encontraron rutinas con cursores explícitos.
                </div>
              )}
            </div>
          )}
        </aside>

        <main className="sql-lab-main">
          <section className="sql-lab-editor-card">
            <header className="sql-lab-editor-toolbar">
              <div className="sql-lab-editor-title">
                <Database size={18} />

                <div>
                  <strong>
                    Editor PostgreSQL
                  </strong>

                  <span>
                    Ctrl + Enter para ejecutar
                  </span>
                </div>
              </div>

              <div className="sql-lab-editor-actions">
                <button
                  type="button"
                  className="sql-lab-button sql-lab-button--secondary"
                  onClick={copiarScript}
                  disabled={!script}
                >
                  {copiado ? (
                    <CheckCircle2
                      size={17}
                    />
                  ) : (
                    <Copy size={17} />
                  )}

                  {copiado
                    ? "Copiado"
                    : "Copiar"}
                </button>

                <button
                  type="button"
                  className="sql-lab-button sql-lab-button--secondary"
                  onClick={limpiarEditor}
                  disabled={
                    ejecutando ||
                    !script
                  }
                >
                  <Eraser size={17} />

                  Limpiar
                </button>

                <button
                  type="button"
                  className="sql-lab-button sql-lab-button--primary"
                  onClick={ejecutarScript}
                  disabled={
                    ejecutando ||
                    modoMocks ||
                    !script.trim()
                  }
                >
                  {ejecutando ? (
                    <Loader2
                      size={18}
                      className="sql-lab-spinner"
                    />
                  ) : (
                    <Play size={18} />
                  )}

                  {ejecutando
                    ? "Ejecutando"
                    : "Ejecutar"}
                </button>
              </div>
            </header>

            <div className="sql-lab-editor">
              <div
                ref={numerosRef}
                className="sql-lab-line-numbers"
                aria-hidden="true"
              >
                {lineas.map(
                  (numero) => (
                    <span key={numero}>
                      {numero}
                    </span>
                  ),
                )}
              </div>

              <textarea
                ref={editorRef}
                value={script}
                onChange={(evento) => {
                  setScript(
                    evento.target.value,
                  );

                  setEjemploSeleccionado(
                    "",
                  );
                }}
                onScroll={
                  sincronizarScroll
                }
                onKeyDown={
                  controlarTeclado
                }
                spellCheck="false"
                autoCapitalize="off"
                autoCorrect="off"
                aria-label="Editor SQL"
                placeholder="Escribe una consulta SQL..."
              />
            </div>

            <footer className="sql-lab-editor-footer">
              <span>
                {lineas.length} líneas
              </span>

              <span>
                {script.length} caracteres
              </span>

              <span>
                PostgreSQL
              </span>
            </footer>
          </section>

          {error && (
            <div className="sql-lab-error">
              <AlertCircle size={21} />

              <div>
                <strong>
                  Error de ejecución
                </strong>

                <pre>
                  {error}
                </pre>
              </div>
            </div>
          )}

          {ejecutando && (
            <section className="sql-lab-running">
              <Loader2
                size={28}
                className="sql-lab-spinner"
              />

              <div>
                <strong>
                  Ejecutando script
                </strong>

                <span>
                  Esperando la respuesta de
                  PostgreSQL...
                </span>
              </div>
            </section>
          )}

          {!ejecutando &&
            respuesta && (
            <section className="sql-lab-results">
              <header className="sql-lab-results-heading">
                <div>
                  <CheckCircle2 size={22} />

                  <div>
                    <h2>
                      Resultado de la ejecución
                    </h2>

                    <p>
                      El script terminó
                      correctamente.
                    </p>
                  </div>
                </div>

                <div className="sql-lab-stats">
                  <div>
                    <Clock3 size={17} />

                    <span>
                      {respuesta.tiempo_ms}
                      {" "}
                      ms
                    </span>
                  </div>

                  <div>
                    <Rows3 size={17} />

                    <span>
                      {totalFilas} filas
                    </span>
                  </div>

                  <div>
                    <Database size={17} />

                    <span>
                      {
                        respuesta.resultados
                          ?.length || 0
                      }
                      {" "}
                      resultados
                    </span>
                  </div>
                </div>
              </header>

              <div className="sql-lab-rollback-message">
                <ShieldCheck size={19} />

                <div>
                  <strong>
                    Cambios revertidos
                  </strong>

                  <span>
                    La base de datos conserva
                    su estado original.
                  </span>
                </div>
              </div>

              {respuesta.mensajes?.length >
                0 && (
                <div className="sql-lab-messages">
                  {respuesta.mensajes.map(
                    (mensaje, indice) => (
                      <p
                        key={`${mensaje}-${indice}`}
                      >
                        {mensaje}
                      </p>
                    ),
                  )}
                </div>
              )}

              <div className="sql-lab-result-list">
                {respuesta.resultados?.map(
                  (resultado) => (
                    <ResultadoTabla
                      key={
                        resultado.indice
                      }
                      resultado={
                        resultado
                      }
                    />
                  ),
                )}
              </div>
            </section>
          )}

          {!ejecutando &&
            !respuesta &&
            !error && (
            <section className="sql-lab-empty-state">
              <Database size={35} />

              <h2>
                Preparado para ejecutar
              </h2>

              <p>
                Selecciona un ejemplo o escribe
                tu propio script SQL y presiona
                Ejecutar.
              </p>
            </section>
          )}
        </main>
      </div>
    </div>
  );
}