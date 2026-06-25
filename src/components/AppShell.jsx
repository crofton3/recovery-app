import BottomNav from "./BottomNav";

export default function AppShell({ active, onChange, children }) {
  return (
    <>
      <div className="app-shell">{children}</div>
      <BottomNav active={active} onChange={onChange} />
    </>
  );
}
