import FoodQuickAdd from "../components/log/FoodQuickAdd";
import CustomFoodForm from "../components/log/CustomFoodForm";
import LoggedFoodList from "../components/log/LoggedFoodList";

export default function LogTab({ data }) {
  return (
    <div className="tab-scroll">
      <FoodQuickAdd onAdd={data.addFood} />
      <CustomFoodForm onAdd={data.addFood} />
      <LoggedFoodList
        logs={data.logs}
        totals={data.totals}
        onDelete={data.deleteFood}
      />
    </div>
  );
}
