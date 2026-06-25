import Card from "../Card";

export default function LoggedFoodList({ logs, totals, onDelete }) {
  return (
    <Card title={`Logged Today · ${logs.length}`}>
      {logs.length === 0 ? (
        <div className="empty">No food logged yet. Tap a quick-add above.</div>
      ) : (
        <>
          {logs.map((item) => (
            <div className="log-item" key={item.id}>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div className="log-name">{item.item_name}</div>
                <div className="log-macros">
                  {item.protein}p · {item.carbs}c · {item.fat}f
                </div>
              </div>
              <div className="log-cal">{item.calories}</div>
              <button
                className="del"
                onClick={() => onDelete(item.id)}
                aria-label="Delete"
              >
                ✕
              </button>
            </div>
          ))}
          <div className="log-total">
            <span className="t-label">Daily total</span>
            <span className="t-val">
              <b>{totals.calories}</b> cal · {totals.protein}p · {totals.carbs}c ·{" "}
              {totals.fat}f
            </span>
          </div>
        </>
      )}
    </Card>
  );
}
