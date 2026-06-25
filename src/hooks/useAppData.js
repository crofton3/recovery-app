import { useState, useEffect, useCallback, useMemo } from "react";
import { supabase, isSupabaseConfigured } from "../lib/supabase";
import { todayStr, sixWeeksAgoStr } from "../lib/date";
import { useToast } from "../context/ToastContext";

const DEFAULT_SETTINGS = {
  surgery_date: sixWeeksAgoStr(),
  calorie_target: 2550,
  protein_target: 190,
  carbs_target: 285,
  fat_target: 75,
  water_target_oz: 110,
};

export function useAppData() {
  const toast = useToast();
  const date = todayStr();

  const [loading, setLoading] = useState(true);
  const [connError, setConnError] = useState(false);
  const [settings, setSettings] = useState(null);
  const [logs, setLogs] = useState([]);
  const [status, setStatus] = useState(null);
  const [checkins, setCheckins] = useState([]);

  // ---------- initial load ----------
  const loadAll = useCallback(async () => {
    if (!isSupabaseConfigured) {
      setConnError(true);
      setLoading(false);
      return;
    }
    try {
      setLoading(true);

      // settings — fetch first row or create defaults
      let { data: s, error: sErr } = await supabase
        .from("user_settings")
        .select("*")
        .order("created_at", { ascending: true })
        .limit(1)
        .maybeSingle();
      if (sErr) throw sErr;
      if (!s) {
        const { data: created, error: cErr } = await supabase
          .from("user_settings")
          .insert(DEFAULT_SETTINGS)
          .select()
          .single();
        if (cErr) throw cErr;
        s = created;
      }
      // backfill a default surgery date if missing
      if (s && !s.surgery_date) {
        const { data: upd } = await supabase
          .from("user_settings")
          .update({ surgery_date: sixWeeksAgoStr() })
          .eq("id", s.id)
          .select()
          .single();
        if (upd) s = upd;
      }
      setSettings(s);

      // today logs
      const { data: l, error: lErr } = await supabase
        .from("daily_logs")
        .select("*")
        .eq("date", date)
        .order("created_at", { ascending: true });
      if (lErr) throw lErr;
      setLogs(l || []);

      // today status — create if missing
      let { data: st, error: stErr } = await supabase
        .from("daily_status")
        .select("*")
        .eq("date", date)
        .maybeSingle();
      if (stErr) throw stErr;
      if (!st) {
        const { data: createdSt, error: csErr } = await supabase
          .from("daily_status")
          .insert({ date, water_oz: 0, collagen_taken: false, meals_checked: {} })
          .select()
          .single();
        if (csErr) throw csErr;
        st = createdSt;
      }
      setStatus(st);

      // checkins (all, newest first)
      const { data: c, error: cinErr } = await supabase
        .from("checkins")
        .select("*")
        .order("date", { ascending: false })
        .order("created_at", { ascending: false });
      if (cinErr) throw cinErr;
      setCheckins(c || []);

      setConnError(false);
    } catch (e) {
      console.error(e);
      setConnError(true);
      toast.error("Couldn't reach Supabase. Check your connection.");
    } finally {
      setLoading(false);
    }
  }, [date]); // eslint-disable-line react-hooks/exhaustive-deps

  useEffect(() => {
    loadAll();
  }, [loadAll]);

  // ---------- derived totals ----------
  const totals = useMemo(() => {
    return logs.reduce(
      (acc, x) => ({
        calories: acc.calories + (x.calories || 0),
        protein: acc.protein + (x.protein || 0),
        carbs: acc.carbs + (x.carbs || 0),
        fat: acc.fat + (x.fat || 0),
      }),
      { calories: 0, protein: 0, carbs: 0, fat: 0 }
    );
  }, [logs]);

  // ---------- settings ----------
  const updateSettings = useCallback(
    async (patch) => {
      if (!settings) return;
      const prev = settings;
      setSettings({ ...settings, ...patch }); // optimistic
      const { data, error } = await supabase
        .from("user_settings")
        .update(patch)
        .eq("id", settings.id)
        .select()
        .single();
      if (error) {
        setSettings(prev);
        toast.error("Save failed");
        return;
      }
      setSettings(data);
      toast.success("Settings saved");
    },
    [settings] // eslint-disable-line react-hooks/exhaustive-deps
  );

  // ---------- food logs ----------
  const addFood = useCallback(
    async (food) => {
      const row = {
        date,
        item_name: food.item_name,
        calories: Number(food.calories) || 0,
        protein: Number(food.protein) || 0,
        carbs: Number(food.carbs) || 0,
        fat: Number(food.fat) || 0,
      };
      const { data, error } = await supabase
        .from("daily_logs")
        .insert(row)
        .select()
        .single();
      if (error) {
        toast.error("Couldn't add food");
        return;
      }
      setLogs((l) => [...l, data]);
      toast.success(`Added ${data.item_name}`);
    },
    [date] // eslint-disable-line react-hooks/exhaustive-deps
  );

  const deleteFood = useCallback(async (id) => {
    const prev = id;
    setLogs((l) => l.filter((x) => x.id !== id)); // optimistic
    const { error } = await supabase.from("daily_logs").delete().eq("id", id);
    if (error) {
      toast.error("Delete failed");
      loadAll();
      return;
    }
    toast.success("Removed");
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  // ---------- daily status helpers ----------
  const patchStatus = useCallback(
    async (patch, silent = false) => {
      if (!status) return;
      const prev = status;
      const next = { ...status, ...patch };
      setStatus(next); // optimistic
      const { data, error } = await supabase
        .from("daily_status")
        .update({ ...patch, updated_at: new Date().toISOString() })
        .eq("id", status.id)
        .select()
        .single();
      if (error) {
        setStatus(prev);
        toast.error("Save failed");
        return;
      }
      setStatus(data);
      if (!silent) toast.success("Saved");
    },
    [status] // eslint-disable-line react-hooks/exhaustive-deps
  );

  const setWater = useCallback(
    (oz) => patchStatus({ water_oz: Math.max(0, oz) }, true),
    [patchStatus]
  );
  const toggleCollagen = useCallback(
    (val) => patchStatus({ collagen_taken: val }),
    [patchStatus]
  );
  const toggleMeal = useCallback(
    (key) => {
      const mc = { ...(status?.meals_checked || {}) };
      mc[key] = !mc[key];
      return patchStatus({ meals_checked: mc }, true);
    },
    [status, patchStatus]
  );

  // ---------- checkins ----------
  const addCheckin = useCallback(async (data) => {
    const row = { date: todayStr(), ...data };
    const { data: created, error } = await supabase
      .from("checkins")
      .insert(row)
      .select()
      .single();
    if (error) {
      toast.error("Couldn't save check-in");
      return false;
    }
    setCheckins((c) => [created, ...c]);
    toast.success("Check-in saved");
    return true;
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  const deleteCheckin = useCallback(async (id) => {
    setCheckins((c) => c.filter((x) => x.id !== id));
    const { error } = await supabase.from("checkins").delete().eq("id", id);
    if (error) {
      toast.error("Delete failed");
      loadAll();
      return;
    }
    toast.success("Check-in removed");
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  return {
    loading,
    connError,
    date,
    settings,
    logs,
    status,
    checkins,
    totals,
    updateSettings,
    addFood,
    deleteFood,
    setWater,
    toggleCollagen,
    toggleMeal,
    addCheckin,
    deleteCheckin,
    reload: loadAll,
  };
}
