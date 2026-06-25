import Card from "../Card";

export default function CollagenToggle({ taken, onToggle }) {
  return (
    <Card title="Recovery Stack">
      <div className="toggle-row" onClick={() => onToggle(!taken)}>
        <div className={`toggle ${taken ? "on" : ""}`}>
          <span className="knob" />
        </div>
        <div style={{ fontSize: 15, fontWeight: 600 }}>
          Collagen + Vitamin C taken
        </div>
      </div>
      <p className="note">
        15g collagen + vitamin C, 30–60 min before PT/lifting.
      </p>
    </Card>
  );
}
