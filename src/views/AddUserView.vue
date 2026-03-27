<script setup>
import { reactive } from 'vue';
import { useRouter } from 'vue-router';
import { useToast } from 'vue-toastification';
import api from '@/api/index';

const router = useRouter();
const toast = useToast();

const form = reactive({
    name: '',
    email: '',
    password: '',
    role: 'USER',
    enabled: true
});

const handleSubmit = async () => {
    try {
        const response = await api.adminUsers.create({
            name: form.name,
            email: form.email,
            password: form.password,
            roles: [form.role],
            enabled: form.enabled
        });
        toast.success('User created successfully');
        router.push(`/users/allusers/${response.data.id}`);
    } catch (error) {
        const msg = error.response?.data?.detail || 'Failed to create user';
        toast.error(msg);
    }
};

</script>

<template>
    <section class="bg-green-50 min-h-screen">
        <div class="container m-auto max-w-2xl py-24">
            <div class="bg-white px-6 py-8 mb-4 shadow-md rounded-md border m-4 md:m-0">
                <form @submit.prevent="handleSubmit">
                    <h2 class="text-3xl text-center font-semibold mb-6">Add User</h2>

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
                        <label class="block text-gray-700 font-bold mb-2">Password</label>
                        <input
                            type="password"
                            v-model="form.password"
                            class="border rounded w-full py-2 px-3"
                            placeholder="Min 5 characters"
                            required
                            minlength="5"
                            maxlength="32"
                        />
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
                            Add User
                        </button>
                    </div>
                </form>
            </div>
        </div>
    </section>
</template>
