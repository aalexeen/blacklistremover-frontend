<script setup>
import PulseLoader from 'vue-spinner/src/PulseLoader.vue';
import BackButtonUsers from '../components/BackButtonUsers.vue';
import { reactive, computed, onMounted } from 'vue';
import { useRoute, RouterLink } from 'vue-router';
import { useToast } from 'vue-toastification';
import { useAuth } from '@/composables/useAuth';
import api from '@/api/index';

const route = useRoute();
const toast = useToast();
const { user: currentUser } = useAuth();

const isSelf = computed(() => String(currentUser.value?.id) === String(userId));

const userId = route.params.id;

const state = reactive({
    user: {},
    isLoading: true
});

const toggleEnabled = async () => {
    try {
        await api.adminUsers.enable(userId, !state.user.enabled);
        state.user.enabled = !state.user.enabled;
        toast.success(`User ${state.user.enabled ? 'enabled' : 'disabled'}`);
    } catch (error) {
        toast.error('Failed to update user status');
    }
};

onMounted(async () => {
    try {
        const response = await api.adminUsers.getById(userId);
        state.user = response.data;
    } catch (error) {
        toast.error('Failed to load user');
    } finally {
        state.isLoading = false;
    }
});
</script>

<template>
    <BackButtonUsers />

    <div v-if="state.isLoading" class="text-center text-gray-500 py-6">
        <PulseLoader />
    </div>

    <section v-else class="bg-green-50">
        <div class="container m-auto py-10 px-6">
            <div class="grid grid-cols-1 md:grid-cols-70/30 w-full gap-6">
                <!-- Main -->
                <main>
                    <div class="bg-white p-6 rounded-lg shadow-md">
                        <div class="flex items-center gap-3 mb-2">
                            <h1 class="text-3xl font-bold">{{ state.user.name }}</h1>
                            <span
                                :class="[
                                    'text-xs font-semibold px-2 py-0.5 rounded-full',
                                    state.user.enabled ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-600'
                                ]">
                                {{ state.user.enabled ? 'Active' : 'Disabled' }}
                            </span>
                        </div>
                        <p class="text-gray-500">{{ state.user.email }}</p>
                    </div>

                    <div class="bg-white p-6 rounded-lg shadow-md mt-6">
                        <h3 class="text-green-800 text-lg font-bold mb-4">Roles</h3>
                        <div class="flex flex-wrap gap-2 mb-6">
                            <span
                                v-for="role in state.user.roles"
                                :key="role"
                                :class="[
                                    'text-sm font-semibold px-3 py-1 rounded-full',
                                    role === 'ADMIN' ? 'bg-purple-100 text-purple-700' : 'bg-blue-100 text-blue-700'
                                ]">
                                {{ role }}
                            </span>
                        </div>

                        <h3 class="text-green-800 text-lg font-bold mb-2">Registered</h3>
                        <p class="text-gray-600">
                            {{ state.user.registered ? new Date(state.user.registered).toLocaleDateString('en-GB') : '—' }}
                        </p>
                    </div>
                </main>

                <!-- Sidebar -->
                <aside>
                    <div class="bg-white p-6 rounded-lg shadow-md">
                        <h3 class="text-xl font-bold mb-4">Manage User</h3>

                        <RouterLink
                            :to="`/users/edit/${state.user.id}`"
                            class="bg-green-500 hover:bg-green-600 text-white text-center font-bold py-2 px-4 rounded-full w-full block transition-colors mb-3">
                            Edit User
                        </RouterLink>

                        <button
                            v-if="!isSelf"
                            @click="toggleEnabled"
                            :class="[
                                'w-full font-bold py-2 px-4 rounded-full block transition-colors mb-3',
                                state.user.enabled
                                    ? 'bg-yellow-400 hover:bg-yellow-500 text-white'
                                    : 'bg-green-400 hover:bg-green-500 text-white'
                            ]">
                            {{ state.user.enabled ? 'Disable User' : 'Enable User' }}
                        </button>

                    </div>
                </aside>
            </div>
        </div>
    </section>
</template>
