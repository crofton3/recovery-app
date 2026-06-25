export default function Card({ title, action, children, className = "" }) {
  return (
    <section className={`card ${className}`}>
      {title && (
        <h2 className={`card-title ${action ? "row" : ""}`}>
          <span>{title}</span>
          {action}
        </h2>
      )}
      {children}
    </section>
  );
}
