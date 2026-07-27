export function Field({ label, name = "", error = "", hint = "", children, className = "" }) {
  return <label className={`field ${className}`}><span className="field__label">{label}</span>{children}{hint && <small>{hint}</small>}{error && <span className="field__error">{error}</span>}</label>;
}

export function Input(props) { return <input className="input" {...props} />; }
export function Select({ children, ...props }) { return <select className="input" {...props}>{children}</select>; }
export function Textarea(props) { return <textarea className="input input--textarea" rows="4" {...props} />; }
export function Checkbox({ label, ...props }) { return <label className="checkbox"><input type="checkbox" {...props} /><span>{label}</span></label>; }
