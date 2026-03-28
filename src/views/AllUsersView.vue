<script setup>
import { reactive, ref, computed, onMounted } from 'vue';
import { RouterLink } from 'vue-router';
import { useToast } from 'vue-toastification';
import { useAuth } from '@/composables/useAuth';
import PulseLoader from 'vue-spinner/src/PulseLoader.vue';
import api from '@/api/index';

const toast = useToast();
const { user: currentUser } = useAuth();

const state = reactive({
    users: [],
    isLoading: true
});

const search = ref('');
const filteredUsers = computed(() => {
    const q = search.value.trim().toLowerCase();
    return state.users.filter(u => {
        if (u.system) return false;
        if (!q) return true;
        return u.name?.toLowerCase().includes(q) || u.email?.toLowerCase().includes(q);
    });
});

const fetchUsers = async () => {
    state.isLoading = true;
    try {
        const response = await api.adminUsers.getAll();
        state.users = response.data;
    } catch (error) {
        toast.error('Failed to load users');
    } finally {
        state.isLoading = false;
    }
};

const toggleEnabled = async (user) => {
    try {
        await api.adminUsers.enable(user.id, !user.enabled);
        user.enabled = !user.enabled;
        toast.success(`User ${user.enabled ? 'enabled' : 'disabled'}`);
    } catch (error) {
        toast.error('Failed to update user status');
    }
};

onMounted(fetchUsers);
</script>

<template>
    <section class="bg-blue-50 min-h-screen px-4 py-10">
        <div class="container-xl lg:container m-auto">
            <!-- Header -->
            <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between mb-6 gap-4">
                <h2 class="text-3xl font-bold text-green-500">Users</h2>
                <RouterLink
                    to="/users/add"
                    class="inline-flex items-center gap-2 bg-green-500 hover:bg-green-600 text-white font-bold py-2 px-5 rounded-lg transition-colors">
                    <i class="pi pi-user-plus"></i>
                    Add User
                </RouterLink>
            </div>

            <!-- Search -->
            <div class="mb-4">
                <input
                    v-model="search"
                    type="text"
                    placeholder="Search by name or email..."
                    class="w-full sm:w-96 border border-gray-300 rounded-lg py-2 px-4 focus:outline-none focus:ring-2 focus:ring-green-400"
                />
            </div>

            <!-- Loading -->
            <div v-if="state.isLoading" class="text-center py-12">
                <PulseLoader />
            </div>

            <!-- Table -->
            <div v-else class="bg-white rounded-xl shadow-md overflow-x-auto">
                <table class="min-w-full divide-y divide-gray-200">
                    <thead class="bg-gray-50">
                        <tr>
                            <th class="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">ID</th>
                            <th class="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Name</th>
                            <th class="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Email</th>
                            <th class="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Roles</th>
                            <th class="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Registered</th>
                            <th class="px-4 py-3 text-center text-xs font-semibold text-gray-500 uppercase tracking-wider">Status</th>
                            <th class="px-4 py-3 text-center text-xs font-semibold text-gray-500 uppercase tracking-wider">Actions</th>
                        </tr>
                    </thead>
                    <tbody class="divide-y divide-gray-100">
                        <tr v-if="filteredUsers.length === 0">
                            <td colspan="7" class="text-center py-8 text-gray-400">No users found</td>
                        </tr>
                        <tr
                            v-for="user in filteredUsers"
                            :key="user.id"
                            :class="['hover:bg-gray-50 transition-colors', !user.enabled && 'opacity-60']">
                            <td class="px-4 py-3 text-sm text-gray-500">{{ user.id }}</td>
                            <td class="px-4 py-3 font-medium text-gray-900">{{ user.name }}</td>
                            <td class="px-4 py-3 text-sm text-gray-600">{{ user.email }}</td>
                            <td class="px-4 py-3">
                                <span
                                    v-for="role in user.roles"
                                    :key="role"
                                    :class="[
                                        'inline-block text-xs font-semibold px-2 py-0.5 rounded-full mr-1',
                                        role === 'ADMIN'
                                            ? 'bg-purple-100 text-purple-700'
                                            : 'bg-blue-100 text-blue-700'
                                    ]">
                                    {{ role }}
                                </span>
                            </td>
                            <td class="px-4 py-3 text-sm text-gray-500">
                                {{ user.registered ? new Date(user.registered).toLocaleDateString('en-GB') : '—' }}
                            </td>
                            <td class="px-4 py-3 text-center">
                                <button
                                    v-if="user.id !== currentUser?.id"
                                    @click="toggleEnabled(user)"
                                    :title="user.enabled ? 'Disable user' : 'Enable user'"
                                    :class="[
                                        'relative inline-flex h-6 w-11 items-center rounded-full transition-colors focus:outline-none',
                                        user.enabled ? 'bg-green-500' : 'bg-gray-300'
                                    ]">
                                    <span
                                        :class="[
                                            'inline-block h-4 w-4 transform rounded-full bg-white shadow transition-transform',
                                            user.enabled ? 'translate-x-6' : 'translate-x-1'
                                        ]">
                                    </span>
                                </button>
                                <span v-else class="text-xs text-gray-400">—</span>
                            </td>
                            <td class="px-4 py-3 text-center">
                                <div class="flex items-center justify-center gap-2">
                                    <RouterLink
                                        :to="`/users/allusers/${user.id}`"
                                        title="View"
                                        class="text-gray-500 hover:text-green-600 transition-colors">
                                        <i class="pi pi-eye text-lg"></i>
                                    </RouterLink>
                                    <RouterLink
                                        :to="`/users/edit/${user.id}`"
                                        title="Edit"
                                        class="text-gray-500 hover:text-blue-600 transition-colors">
                                        <i class="pi pi-pencil text-lg"></i>
                                    </RouterLink>
                                </div>
                            </td>
                        </tr>
                    </tbody>
                </table>

                <div class="px-4 py-2 text-sm text-gray-400 border-t">
                    Total: {{ filteredUsers.length }} user(s)
                </div>
            </div>
        </div>
    </section>

</template>
