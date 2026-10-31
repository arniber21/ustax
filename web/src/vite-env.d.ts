/// <reference types="vite/client" />

interface ImportMetaEnv {
  /** Base URL of the calculator server. Default http://localhost:8080. */
  readonly VITE_API_URL?: string;
  /** "1" serves api/fixtures instead of calling the server. */
  readonly VITE_API_MOCK?: string;
}
