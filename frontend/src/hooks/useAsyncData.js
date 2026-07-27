import { useCallback, useEffect, useState } from "react";

export default function useAsyncData(loader, dependencies = [], immediate = true) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(immediate);
  const [error, setError] = useState("");

  const reload = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const result = await loader();
      setData(result);
      return result;
    } catch (err) {
      setError(err.message || "No se pudo cargar la información");
      return null;
    } finally {
      setLoading(false);
    }
  }, dependencies);

  useEffect(() => { if (immediate) reload(); }, [reload, immediate]);
  return { data, setData, loading, error, reload };
}
