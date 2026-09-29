import react from '@vitejs/plugin-react'
import { defineConfig, loadEnv } from 'vite'
import { validateApplicationConfig } from './src/config/productionConfig.ts'
import { assertProductionBoundary } from './scripts/production-boundary.mjs'

export default defineConfig(({command,mode}) => {
  if (command === 'build') {
    // Validate before Vite can embed public environment values in artifacts.
    validateApplicationConfig({...loadEnv(mode,process.cwd(),'VITE_'),...Object.fromEntries(Object.entries(process.env).filter(([name])=>name.startsWith('VITE_')))}, false)
    assertProductionBoundary(process.cwd())
  }
  return {plugins:[react()]}
})
