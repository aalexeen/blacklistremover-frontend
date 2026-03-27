<script setup>
import { ref, reactive, onMounted } from 'vue';
import { useAuth } from '@/composables/useAuth';
import { useToast } from 'vue-toastification';
import PulseLoader from 'vue-spinner/src/PulseLoader.vue';
import axios from 'axios';

const { getProfile } = useAuth();
const toast = useToast();

const userProfile = ref(null);
const isLoading = ref(true);
const error = ref(null);

// Edit Profile modal
const showEditModal = ref(false);
const editForm = reactive({ name: '', email: '' });
const editLoading = ref(false);

// Change Password modal
const showPasswordModal = ref(false);
const passwordForm = reactive({ currentPassword: '', newPassword: '', confirmPassword: '' });
const showCurrentPassword = ref(false);
const showNewPassword = ref(false);
const passwordLoading = ref(false);

const fetchUserProfile = async () => {
    try {
        isLoading.value = true;
        error.value = null;
        const profile = await getProfile();
        userProfile.value = profile;
    } catch (err) {
        console.error('Error fetching user profile:', err);
        error.value = err;
        toast.error('Failed to load user profile');
    } finally {
        isLoading.value = false;
    }
};

onMounted(() => {
    fetchUserProfile();
});

const formatDate = (dateString) => {
    if (!dateString) return 'Not available';
    try {
        return new Date(dateString).toLocaleDateString('en-US', {
            year: 'numeric',
            month: 'long',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
    } catch (e) {
        return 'Invalid date';
    }
};

const refreshProfile = () => {
    fetchUserProfile();
};

const openEditModal = () => {
    editForm.name = userProfile.value.name || '';
    editForm.email = userProfile.value.email || '';
    showEditModal.value = true;
};

const submitEditProfile = async () => {
    editLoading.value = true;
    try {
        const email = localStorage.getItem('email');
        const password = localStorage.getItem('password');
        await axios.put('/api/profile', {
            name: editForm.name,
            email: editForm.email,
            password: password
        }, {
            headers: {
                Authorization: `Basic ${btoa(`${email}:${password}`)}`
            }
        });
        // If email changed, update localStorage
        if (editForm.email !== email) {
            localStorage.setItem('email', editForm.email);
        }
        toast.success('Profile updated successfully');
        showEditModal.value = false;
        await fetchUserProfile();
    } catch (err) {
        const msg = err.response?.data?.detail || 'Failed to update profile';
        toast.error(msg);
    } finally {
        editLoading.value = false;
    }
};

const openPasswordModal = () => {
    passwordForm.currentPassword = '';
    passwordForm.newPassword = '';
    passwordForm.confirmPassword = '';
    showPasswordModal.value = true;
};

const submitChangePassword = async () => {
    if (passwordForm.newPassword !== passwordForm.confirmPassword) {
        toast.error('New passwords do not match');
        return;
    }
    passwordLoading.value = true;
    try {
        const email = localStorage.getItem('email');
        // PUT /api/profile with new password — verifies current password via Basic Auth
        await axios.put('/api/profile', {
            name: userProfile.value.name,
            email: userProfile.value.email,
            password: passwordForm.newPassword
        }, {
            headers: {
                Authorization: `Basic ${btoa(`${email}:${passwordForm.currentPassword}`)}`
            }
        });
        // Update stored password
        localStorage.setItem('password', passwordForm.newPassword);
        toast.success('Password changed successfully');
        showPasswordModal.value = false;
    } catch (err) {
        if (err.response?.status === 401) {
            toast.error('Current password is incorrect');
        } else {
            const msg = err.response?.data?.detail || 'Failed to change password';
            toast.error(msg);
        }
    } finally {
        passwordLoading.value = false;
    }
};
</script>

<template>
    <section class="bg-green-50 min-h-screen">
        <div class="container m-auto py-10 px-6">

            <!-- Page Header -->
            <div class="text-center mb-10">
                <h1 class="text-4xl font-bold text-green-700 mb-4">My Account</h1>
                <p class="text-gray-600">Manage your account information and settings</p>
            </div>

            <!-- Loading Spinner -->
            <div v-if="isLoading" class="text-center text-gray-500 py-6">
                <PulseLoader />
            </div>

            <!-- Error State -->
            <div v-else-if="error" class="text-center py-12">
                <div class="bg-red-50 border border-red-200 rounded-lg p-6 max-w-md mx-auto">
                    <div class="text-red-500 mb-4">
                        <svg class="w-12 h-12 mx-auto" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.728-.833-2.498 0L4.316 15.5c-.77.833.192 2.5 1.732 2.5z" />
                        </svg>
                    </div>
                    <h2 class="text-xl font-bold text-red-700 mb-2">Unable to Load Profile</h2>
                    <p class="text-red-600 mb-4">There was an error loading your profile information.</p>
                    <button
                        @click="refreshProfile"
                        class="bg-red-500 hover:bg-red-600 text-white font-bold py-2 px-4 rounded transition-colors">
                        Try Again
                    </button>
                </div>
            </div>

            <!-- User Profile Content -->
            <div v-else-if="userProfile" class="max-w-4xl mx-auto">
                <div class="grid grid-cols-1 md:grid-cols-2 gap-6">

                    <!-- Basic Information -->
                    <div class="bg-white p-6 rounded-lg shadow-md">
                        <div class="flex items-center justify-between mb-6">
                            <h2 class="text-2xl font-bold text-green-700">Basic Information</h2>
                            <button
                                @click="refreshProfile"
                                class="text-green-600 hover:text-green-700 p-2 rounded-full hover:bg-green-50 transition-colors"
                                title="Refresh profile">
                                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
                                </svg>
                            </button>
                        </div>

                        <div class="space-y-4">
                            <div>
                                <label class="block text-sm font-medium text-gray-700 mb-1">Full Name</label>
                                <p class="text-gray-900 bg-gray-50 p-3 rounded border">
                                    {{ userProfile.name || 'Not specified' }}
                                </p>
                            </div>

                            <div>
                                <label class="block text-sm font-medium text-gray-700 mb-1">Email Address</label>
                                <p class="text-gray-900 bg-gray-50 p-3 rounded border">
                                    {{ userProfile.email || 'Not specified' }}
                                </p>
                            </div>

                        </div>
                    </div>

                    <!-- Account Status -->
                    <div class="bg-white p-6 rounded-lg shadow-md">
                        <h2 class="text-2xl font-bold text-green-700 mb-6">Account Status</h2>

                        <div class="space-y-4">
                            <div>
                                <label class="block text-sm font-medium text-gray-700 mb-1">Account Status</label>
                                <div class="p-3 rounded border" :class="[
                                    userProfile.enabled
                                        ? 'text-green-800 bg-green-50 border-green-200'
                                        : 'text-red-800 bg-red-50 border-red-200'
                                ]">
                                    <div class="flex items-center">
                                        <div class="w-3 h-3 rounded-full mr-2" :class="[
                                            userProfile.enabled ? 'bg-green-500' : 'bg-red-500'
                                        ]"></div>
                                        {{ userProfile.enabled ? 'Active' : 'Inactive' }}
                                    </div>
                                </div>
                            </div>

                            <div>
                                <label class="block text-sm font-medium text-gray-700 mb-1">Member Since</label>
                                <p class="text-gray-900 bg-gray-50 p-3 rounded border">
                                    {{ formatDate(userProfile.registered) }}
                                </p>
                            </div>

                            <div>
                                <label class="block text-sm font-medium text-gray-700 mb-1">User Roles</label>
                                <div class="bg-gray-50 p-3 rounded border">
                                    <div v-if="userProfile.roles && userProfile.roles.length > 0" class="flex flex-wrap gap-2">
                                        <span
                                            v-for="role in userProfile.roles"
                                            :key="role"
                                            :class="[
                                                'inline-block text-xs font-medium px-2.5 py-1 rounded-full',
                                                role === 'ADMIN' ? 'bg-purple-100 text-purple-700' : 'bg-blue-100 text-blue-800'
                                            ]">
                                            {{ role }}
                                        </span>
                                    </div>
                                    <p v-else class="text-gray-500 text-sm">No roles assigned</p>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Actions Section -->
                <div class="bg-white p-6 rounded-lg shadow-md mt-6">
                    <h2 class="text-2xl font-bold text-green-700 mb-6">Account Actions</h2>
                    <div class="flex flex-wrap gap-4">
                        <button
                            class="bg-green-500 hover:bg-green-600 text-white font-bold py-2 px-6 rounded-lg transition-colors"
                            @click="openEditModal">
                            Edit Profile
                        </button>
                        <button
                            class="bg-blue-500 hover:bg-blue-600 text-white font-bold py-2 px-6 rounded-lg transition-colors"
                            @click="openPasswordModal">
                            Change Password
                        </button>
                    </div>
                </div>
            </div>
        </div>
    </section>

    <!-- Edit Profile Modal -->
    <Teleport to="body">
        <div v-if="showEditModal" class="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
            <div class="bg-white rounded-xl shadow-xl p-6 max-w-md w-full mx-4">
                <h3 class="text-xl font-bold mb-4">Edit Profile</h3>
                <form @submit.prevent="submitEditProfile">
                    <div class="mb-4">
                        <label class="block text-gray-700 font-bold mb-2">Full Name</label>
                        <input
                            type="text"
                            v-model="editForm.name"
                            class="border rounded w-full py-2 px-3"
                            required
                            minlength="2"
                            maxlength="128"
                        />
                    </div>
                    <div class="mb-6">
                        <label class="block text-gray-700 font-bold mb-2">Email</label>
                        <input
                            type="email"
                            v-model="editForm.email"
                            class="border rounded w-full py-2 px-3"
                            required
                            maxlength="128"
                        />
                    </div>
                    <div class="flex gap-3 justify-end">
                        <button
                            type="button"
                            @click="showEditModal = false"
                            class="px-4 py-2 rounded-lg border border-gray-300 hover:bg-gray-50 text-sm font-medium transition-colors">
                            Cancel
                        </button>
                        <button
                            type="submit"
                            :disabled="editLoading"
                            class="px-4 py-2 rounded-lg bg-green-500 hover:bg-green-600 text-white text-sm font-medium transition-colors disabled:opacity-50">
                            {{ editLoading ? 'Saving...' : 'Save' }}
                        </button>
                    </div>
                </form>
            </div>
        </div>
    </Teleport>

    <!-- Change Password Modal -->
    <Teleport to="body">
        <div v-if="showPasswordModal" class="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
            <div class="bg-white rounded-xl shadow-xl p-6 max-w-md w-full mx-4">
                <h3 class="text-xl font-bold mb-4">Change Password</h3>
                <form @submit.prevent="submitChangePassword">
                    <div class="mb-4">
                        <label class="block text-gray-700 font-bold mb-2">Current Password</label>
                        <div class="relative">
                            <input
                                :type="showCurrentPassword ? 'text' : 'password'"
                                v-model="passwordForm.currentPassword"
                                class="border rounded w-full py-2 px-3 pr-10"
                                required
                            />
                            <button type="button" @click="showCurrentPassword = !showCurrentPassword"
                                class="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600">
                                <i :class="showCurrentPassword ? 'pi pi-eye-slash' : 'pi pi-eye'"></i>
                            </button>
                        </div>
                    </div>
                    <div class="mb-4">
                        <label class="block text-gray-700 font-bold mb-2">New Password</label>
                        <div class="relative">
                            <input
                                :type="showNewPassword ? 'text' : 'password'"
                                v-model="passwordForm.newPassword"
                                class="border rounded w-full py-2 px-3 pr-10"
                                required
                                minlength="5"
                                maxlength="32"
                            />
                            <button type="button" @click="showNewPassword = !showNewPassword"
                                class="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600">
                                <i :class="showNewPassword ? 'pi pi-eye-slash' : 'pi pi-eye'"></i>
                            </button>
                        </div>
                    </div>
                    <div class="mb-6">
                        <label class="block text-gray-700 font-bold mb-2">Confirm New Password</label>
                        <input
                            type="password"
                            v-model="passwordForm.confirmPassword"
                            class="border rounded w-full py-2 px-3"
                            required
                            minlength="5"
                            maxlength="32"
                        />
                    </div>
                    <div class="flex gap-3 justify-end">
                        <button
                            type="button"
                            @click="showPasswordModal = false"
                            class="px-4 py-2 rounded-lg border border-gray-300 hover:bg-gray-50 text-sm font-medium transition-colors">
                            Cancel
                        </button>
                        <button
                            type="submit"
                            :disabled="passwordLoading"
                            class="px-4 py-2 rounded-lg bg-blue-500 hover:bg-blue-600 text-white text-sm font-medium transition-colors disabled:opacity-50">
                            {{ passwordLoading ? 'Saving...' : 'Change Password' }}
                        </button>
                    </div>
                </form>
            </div>
        </div>
    </Teleport>
</template>
