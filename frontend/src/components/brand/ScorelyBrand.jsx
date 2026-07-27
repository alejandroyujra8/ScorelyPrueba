import {
  Link,
} from "react-router-dom";

export default function ScorelyBrand({
  light = false,
  to = "/dashboard",
}) {
  return (
    <Link
      className={`scorely-brand ${
        light
          ? "scorely-brand--light"
          : ""
      }`}
      to={to}
      aria-label="Ir al inicio de Scorely"
    >
      <span
        className="scorely-brand__mark"
        aria-hidden="true"
      >
        <span className="scorely-brand__letter">
          S
        </span>

        <span className="scorely-brand__accent" />
      </span>

      <span className="scorely-brand__word">
        SCORELY
      </span>
    </Link>
  );
}