import { humanizeStatus, statusTone } from "../../utils/status";

export default function Badge({ value, tone = "" }) {
  return <span className={`badge badge--${tone || statusTone(value)}`}>{humanizeStatus(value)}</span>;
}
