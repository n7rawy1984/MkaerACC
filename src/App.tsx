import { Route, Routes } from "react-router-dom";
import { AppShell } from "./components/layout/AppShell";
import { AppDataProvider } from "./state/AppDataContext";
import { Dashboard } from "./pages/Dashboard";
import { Projects } from "./pages/Projects";
import { ProjectDetail } from "./pages/ProjectDetail";
import { Expenses } from "./pages/Expenses";
import { Advances } from "./pages/Advances";
import { Suppliers } from "./pages/Suppliers";
import { Subcontractors } from "./pages/Subcontractors";
import { SubcontractDetail } from "./pages/SubcontractDetail";
import { OwnersCustodians } from "./pages/OwnersCustodians";
import { Journal } from "./pages/Journal";

export default function App() {
  return (
    <AppDataProvider>
      <AppShell>
        <Routes>
          <Route path="/" element={<Dashboard />} />
          <Route path="/projects" element={<Projects />} />
          <Route path="/projects/:id" element={<ProjectDetail />} />
          <Route path="/expenses" element={<Expenses />} />
          <Route path="/advances" element={<Advances />} />
          <Route path="/suppliers" element={<Suppliers />} />
          <Route path="/subcontractors" element={<Subcontractors />} />
          <Route path="/subcontractors/:id" element={<SubcontractDetail />} />
          <Route path="/people" element={<OwnersCustodians />} />
          <Route path="/journal" element={<Journal />} />
        </Routes>
      </AppShell>
    </AppDataProvider>
  );
}
