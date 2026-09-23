package internalapi

// Handler exposes permission-checked endpoints accessible strictly by the AI service.
// The AI service calls these endpoints to query facts and trigger actions without direct database access.
type Handler struct{}
