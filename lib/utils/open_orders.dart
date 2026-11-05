/// "Em aberto": the orders still to be done (quotes count). The Início
/// filter, its query and the Clientes counts read this list, in the app and
/// on the server (docs/web-app/contract-cases/customer-summary.json).
const kOpenOrderStatuses = ['quote', 'approved', 'progress'];

bool isOpenOrderStatus(String? status) => kOpenOrderStatuses.contains(status);

/// "Em aberto" loads every open order at once: the next-step block, the
/// sections and the "12 em aberto" count must see all of them, not a page.
/// Clientes reads the same query with the same limit.
const int kOpenOrdersLimit = 500;
