<script setup>
import { reactive, ref, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useToast } from 'vue-toastification';
import PulseLoader from 'vue-spinner/src/PulseLoader.vue';
import api from '@/api/index';

const route = useRoute();
const router = useRouter();
const toast = useToast();

const userId = route.params.id;

const state = reactive({
    isLoading: true
});

const form = reactive({
    id: null,
    name: '',
    email: '',
    password: '',
    role: 'USER',
    enabled: true
});

const showPassword = ref(false);

const handleSubmit = async () => {
    try {
        const payload = {
            id: Number(userId),
            name: form.name,
            email: form.email,
            roles: [form.role],
            enabled: form.enabled
        };
        if (form.password) {
            payload.password = form.password;
        }
        await api.adminUsers.update(userId, payload);
        toast.success('User updated successfully');
        router.push(`/users/allusers/${userId}`);
    } catch (error) {
        const msg = error.response?.data?.detail || 'Failed to update user';
        toast.error(msg);
    }
};

onMounted(async () => {
    try {
        const response = await api.adminUsers.getById(userId);
        const user = response.data;
        form.name = user.name;
        form.email = user.email;
        form.role = user.roles?.includes('ADMIN') ? 'ADMIN' : 'USER';
        form.enabled = user.enabled;
    } catch (error) {
        toast.error('Failed to load user data');
    } finally {
        state.isLoading = false;
    }
});
</script>

<template>
    <div v-if="state.isLoading" class="text-center py-12">
        <PulseLoader />
    </div>

    <section v-else class="bg-green-50 min-h-screen">
        <div class="container m-auto max-w-2xl py-24">
            <div class="bg-white px-6 py-8 mb-4 shadow-md rounded-md border m-4 md:m-0">
                <form @submit.prevent="handleSubmit">
                    <h2 class="text-3xl text-center font-semibold mb-6">Edit User</h2>

                    <div class="mb-4">
                        <label class="block text-gray-700 font-bold mb-2">Name</label>
                        <input
                            type="text"
                            v-model="form.name"
                            class="border rounded w-full py-2 px-3"
                            placeholder="Full name"
                            required
                            minlength="2"
                            maxlength="128"
                        />
                    </div>

                    <div class="mb-4">
                        <label class="block text-gray-700 font-bold mb-2">Email</label>
                        <input
                            type="email"
                            v-model="form.email"
                            class="border rounded w-full py-2 px-3"
                            placeholder="user@example.com"
                            required
                            maxlength="128"
                        />
                    </div>

                    <div class="mb-4">
                        <label class="block text-gray-700 font-bold mb-2">
                            New Password
                            <span class="text-gray-400 font-normal text-sm ml-1">(leave empty to keep current)</span>
                        </label>
                        <div class="relative">
                            <input
                                :type="showPassword ? 'text' : 'password'"
                                v-model="form.password"
                                class="border rounded w-full py-2 px-3 pr-10"
                                placeholder="Min 5 characters"
                                minlength="5"
                                maxlength="32"
                            />
                            <button
                                type="button"
                                @click="showPassword = !showPassword"
                                class="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600">
                                <i :class="showPassword ? 'pi pi-eye-slash' : 'pi pi-eye'"></i>
                            </button>
                        </div>
                    </div>

                    <div class="mb-4">
                        <label class="block text-gray-700 font-bold mb-2">Role</label>
                        <div class="flex gap-6">
                            <label class="flex items-center gap-2 cursor-pointer">
                                <input
                                    type="radio"
                                    value="USER"
                                    v-model="form.role"
                                    class="w-4 h-4 accent-green-500"
                                />
                                <span class="bg-blue-100 text-blue-700 text-sm font-semibold px-2 py-0.5 rounded-full">USER</span>
                            </label>
                            <label class="flex items-center gap-2 cursor-pointer">
                                <input
                                    type="radio"
                                    value="ADMIN"
                                    v-model="form.role"
                                    class="w-4 h-4 accent-green-500"
                                />
                                <span class="bg-purple-100 text-purple-700 text-sm font-semibold px-2 py-0.5 rounded-full">ADMIN</span>
                            </label>
                        </div>
                    </div>

                    <div class="mb-6">
                        <label class="flex items-center gap-3 cursor-pointer">
                            <span class="text-gray-700 font-bold">Account enabled</span>
                            <button
                                type="button"
                                @click="form.enabled = !form.enabled"
                                :class="[
                                    'relative inline-flex h-6 w-11 items-center rounded-full transition-colors focus:outline-none',
                                    form.enabled ? 'bg-green-500' : 'bg-gray-300'
                                ]">
                                <span
                                    :class="[
                                        'inline-block h-4 w-4 transform rounded-full bg-white shadow transition-transform',
                                        form.enabled ? 'translate-x-6' : 'translate-x-1'
                                    ]">
                                </span>
                            </button>
                        </label>
                    </div>

                    <div class="flex gap-3">
                        <button
                            type="button"
                            @click="$router.back()"
                            class="flex-1 border border-gray-300 hover:bg-gray-50 text-gray-700 font-bold py-2 px-4 rounded-full transition-colors">
                            Cancel
                        </button>
                        <button
                            type="submit"
                            class="flex-1 bg-green-500 hover:bg-green-600 text-white font-bold py-2 px-4 rounded-full transition-colors">
                            Save Changes
                        </button>
                    </div>
                </form>
            </div>
        </div>
    </section>
</template>
