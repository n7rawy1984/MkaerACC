import { createContext, useContext } from "react";
import type { ProductionMasterDataContextValue } from "./masterTypes";

export const ProductionMasterDataContext = createContext<ProductionMasterDataContextValue | null>(null);

export function useProductionMasterData(): ProductionMasterDataContextValue {
  const value = useContext(ProductionMasterDataContext);
  if (!value) throw new Error("useProductionMasterData must be used within ProductionMasterDataProvider");
  return value;
}
