import Card from "../Card";

export default function PlanCard({ title, children }) {
  return <Card title={title}>{children}</Card>;
}
