import Modal from "./Modal";

export default function ConfirmDialog({
  open,
  onClose,
  onConfirm,
  title = "Confirmar acción",
  message,
  busy = false,
  confirmLabel = "Confirmar",
  confirmVariant = "danger",
}) {
  return (
    <Modal
      open={open}
      onClose={onClose}
      title={title}
    >
      <p className="confirm-message">
        {message}
      </p>

      <div className="modal-actions">
        <button
          className="button button--secondary"
          type="button"
          onClick={onClose}
          disabled={busy}
        >
          Cancelar
        </button>

        <button
          className={`button button--${confirmVariant}`}
          type="button"
          disabled={busy}
          onClick={onConfirm}
        >
          {busy
            ? "Procesando..."
            : confirmLabel}
        </button>
      </div>
    </Modal>
  );
}