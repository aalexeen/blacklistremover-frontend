// api - 3rd step
import instance from "./instance";

import blockedmacsModule from "./blockedmacs";
import authModule from "./authentication";
import adminUsersModule from "./adminusers";
import deletedMacsModule from "./deletedmacs";

export default {
    blockedmacs: blockedmacsModule(instance),
    authentication: authModule(instance),
    adminUsers: adminUsersModule(instance),
    deletedMacs: deletedMacsModule(instance)
}