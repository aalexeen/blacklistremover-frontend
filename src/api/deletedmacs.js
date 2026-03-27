// Admin Deleted MACs history API - requires ADMIN role
// Base path: /api/admin/deleted_macs

export default function ({ admin }) {
    return {
        getAll({ page = 0, size = 50, mac, userId, reason, dateFrom, dateTo } = {}, config = {}) {
            const params = { page, size };
            if (mac) params.mac = mac;
            if (userId !== undefined && userId !== null) params.userId = userId;
            if (reason) params.reason = reason;
            if (dateFrom) params.dateFrom = dateFrom;
            if (dateTo) params.dateTo = dateTo;
            return admin.get('deleted_macs', { params, ...config });
        }
    };
}
