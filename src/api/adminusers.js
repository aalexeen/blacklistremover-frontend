// Admin Users API - requires ADMIN role
// Base path: /api/admin/users

export default function ({ admin }) {
    return {
        getAll(config = {}) {
            return admin.get('users', config);
        },
        getById(id, config = {}) {
            return admin.get(`users/${id}`, config);
        },
        getByEmail(email, config = {}) {
            return admin.get('users/by-email', { params: { email }, ...config });
        },
        create(userData, config = {}) {
            return admin.post('users', userData, config);
        },
        update(id, userData, config = {}) {
            return admin.put(`users/${id}`, userData, config);
        },
        enable(id, enabled, config = {}) {
            return admin.patch(`users/${id}`, undefined, { params: { enabled }, ...config });
        }
    };
}
