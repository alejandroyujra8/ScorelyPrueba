export const ROLES = Object.freeze({
  ADMINISTRADOR: "ADMINISTRADOR",
  ORGANIZADOR: "ORGANIZADOR",
  ARBITRO: "ARBITRO",
  JUGADOR: "JUGADOR",
  CONSULTA: "CONSULTA",
});

export const ALL_ROLES =
  Object.values(ROLES);

export const MANAGER_ROLES = [
  ROLES.ADMINISTRADOR,
  ROLES.ORGANIZADOR,
];

export const MATCH_OPERATOR_ROLES = [
  ...MANAGER_ROLES,
  ROLES.ARBITRO,
];

export const PERMISSIONS = Object.freeze({
  MANAGE_USERS: "MANAGE_USERS",
  MANAGE_CATALOGS: "MANAGE_CATALOGS",
  MANAGE_TEAMS: "MANAGE_TEAMS",
  MANAGE_PLAYERS: "MANAGE_PLAYERS",
  MANAGE_TOURNAMENTS:
    "MANAGE_TOURNAMENTS",
  MANAGE_REGISTRATIONS:
    "MANAGE_REGISTRATIONS",
  MANAGE_PAYMENTS: "MANAGE_PAYMENTS",
  SCHEDULE_MATCHES: "SCHEDULE_MATCHES",
  ASSIGN_REFEREES: "ASSIGN_REFEREES",
  OPERATE_MATCHES: "OPERATE_MATCHES",
  VIEW_REPORTS: "VIEW_REPORTS",
  VIEW_AUDIT: "VIEW_AUDIT",
  USE_SQL_LAB: "USE_SQL_LAB",
});

const rolePermissions = {
  [ROLES.ADMINISTRADOR]:
    Object.values(PERMISSIONS),

  [ROLES.ORGANIZADOR]: [
    PERMISSIONS.MANAGE_CATALOGS,
    PERMISSIONS.MANAGE_TEAMS,
    PERMISSIONS.MANAGE_PLAYERS,
    PERMISSIONS.MANAGE_TOURNAMENTS,
    PERMISSIONS.MANAGE_REGISTRATIONS,
    PERMISSIONS.MANAGE_PAYMENTS,
    PERMISSIONS.SCHEDULE_MATCHES,
    PERMISSIONS.ASSIGN_REFEREES,
    PERMISSIONS.OPERATE_MATCHES,
    PERMISSIONS.VIEW_REPORTS,
  ],

  [ROLES.ARBITRO]: [
    PERMISSIONS.OPERATE_MATCHES,
    PERMISSIONS.VIEW_REPORTS,
  ],

  [ROLES.JUGADOR]: [
    PERMISSIONS.VIEW_REPORTS,
  ],

  [ROLES.CONSULTA]: [
    PERMISSIONS.VIEW_REPORTS,
  ],
};

export function normalizeRoles(
  roles = [],
) {
  return Array.isArray(roles)
    ? [
        ...new Set(
          roles.map((role) =>
            String(role).toUpperCase(),
          ),
        ),
      ]
    : [];
}

export function hasRole(
  user,
  roles,
) {
  const required = Array.isArray(roles)
    ? roles
    : [roles];

  const current =
    normalizeRoles(user?.roles);

  return (
    required.length === 0 ||
    required.some((role) =>
      current.includes(role),
    )
  );
}

export function hasPermission(
  user,
  permission,
) {
  return normalizeRoles(
    user?.roles,
  ).some((role) =>
    rolePermissions[role]?.includes(
      permission,
    ),
  );
}

export function canManage(
  user,
) {
  return hasRole(
    user,
    MANAGER_ROLES,
  );
}

export const navigationItems = [
  {
    label: "Inicio",
    path: "/dashboard",
    key: "dashboard",
    roles: ALL_ROLES,
  },
  {
    label: "Torneos",
    path: "/torneos",
    key: "torneos",
    roles: ALL_ROLES,
  },
  {
    label: "Equipos",
    path: "/equipos",
    key: "equipos",
    roles: [
      ROLES.ADMINISTRADOR,
      ROLES.ORGANIZADOR,
      ROLES.JUGADOR,
    ],
  },
  {
    label: "Partidos",
    path: "/partidos",
    key: "partidos",
    roles: ALL_ROLES,
  },
  {
    label: "Reportes",
    path: "/reportes",
    key: "reportes",
    roles: ALL_ROLES,
  },
  {
    label: "Usuarios",
    path: "/usuarios",
    key: "usuarios",
    roles: [ROLES.ADMINISTRADOR],
  },
  {
    label: "Deportes",
    path: "/deportes",
    key: "deportes",
    roles: MANAGER_ROLES,
  },
  {
    label: "Jugadores",
    path: "/jugadores",
    key: "jugadores",
    roles: MANAGER_ROLES,
  },
  {
    label: "Inscripciones",
    path: "/inscripciones",
    key: "inscripciones",
    roles: MANAGER_ROLES,
  },
  {
    label: "Laboratorio SQL",
    path: "/laboratorio-sql",
    key: "laboratorio-sql",
    roles: [ROLES.ADMINISTRADOR],
  },
  {
    label: "Auditoría",
    path: "/auditoria",
    key: "auditoria",
    roles: [
      ROLES.ADMINISTRADOR,
    ],
  },
];

export function getNavigationForUser(
  user,
) {
  return navigationItems.filter(
    (item) =>
      hasRole(
        user,
        item.roles,
      ),
  );
}