import { createContext, useContext } from "react";
import type { ProductionMasterDataState } from "./masterTypes";

export const ProductionMasterDataContext = createContext<ProductionMasterDataState | null>(null);

export function useProductionMasterData(): ProductionMasterDataState {
  const value = useContext(ProductionMasterDataContext);
  if (!value) throw new Error("useProductionMasterData must be used within ProductionMasterDataProvider");
  return value;
}
