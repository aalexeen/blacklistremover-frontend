<script setup>
import logo from '@/assets/img/logo.png';
import { RouterLink, useRoute, useRouter } from 'vue-router';
import { ref, onMounted, watch } from 'vue';
import { useAuth } from '@/composables/useAuth';
import { useToast } from 'vue-toastification';

const route = useRoute();
const router = useRouter();
const toast = useToast();

const {
  isLoggedIn,
  username,
  logout,
  initializeAuth,
  isAdmin,
  isUser,
  hasRole,
  userRoles
} = useAuth();

const menuOpen = ref(false);

// Close menu on route change
watch(() => route.path, () => { menuOpen.value = false; });

onMounted(async () => {
  await initializeAuth();
});

const handleLogout = async () => {
  try {
    await logout();
    toast.success('Logged out successfully');
    router.push('/login');
  } catch (error) {
    console.error('Logout error:', error);
    toast.error('Logout failed');
  }
};

const isActiveLink = (routerPath) => route.path === routerPath;

const isRemoveMacActive = () =>
  route.path === '/removemac' || route.path === '/removemac-table';

const canAccessAdminRoutes = () => isAdmin.value;
const canAccessUserManagement = () => hasRole('ADMIN');
</script>

<template>
  <nav class="bg-green-700 border-b border-green-500">
    <div class="mx-auto w-full px-2 sm:px-6 lg:px-8">
      <div class="flex h-20 items-center justify-between">

        <!-- Logo -->
        <RouterLink class="flex flex-shrink-0 items-center" to="/">
          <img class="h-10 w-auto" :src="logo" alt="Blacklistremover" />
          <span class="hidden md:block text-white text-2xl font-bold ml-2">Blacklistremover</span>
        </RouterLink>

        <!-- Desktop menu -->
        <div v-if="isLoggedIn" class="hidden md:flex items-center space-x-2">
          <RouterLink
            to="/"
            :class="[isActiveLink('/') ? 'bg-green-900' : 'hover:bg-gray-900 hover:text-white',
              'text-white px-3 py-2 rounded-md']">
            Home
          </RouterLink>

          <RouterLink
            v-if="hasRole('USER') || hasRole('ADMIN')"
            to="/removemac-table"
            :class="[isRemoveMacActive() ? 'bg-green-900' : 'hover:bg-gray-900 hover:text-white',
              'text-white px-3 py-2 rounded-md']">
            Remove mac
          </RouterLink>

          <template v-if="canAccessAdminRoutes()">
            <RouterLink
              to="/users/allusers"
              :class="[isActiveLink('/users/allusers') ? 'bg-green-900' : 'hover:bg-gray-900 hover:text-white',
                'text-white px-3 py-2 rounded-md']">
              All Users
            </RouterLink>

            <RouterLink
              to="/users/add"
              :class="[isActiveLink('/users/add') ? 'bg-green-900' : 'hover:bg-gray-900 hover:text-white',
                'text-white px-3 py-2 rounded-md']">
              Add User
            </RouterLink>

            <RouterLink
              to="/history"
              :class="[isActiveLink('/history') ? 'bg-green-900' : 'hover:bg-gray-900 hover:text-white',
                'text-white px-3 py-2 rounded-md']">
              Deletion History
            </RouterLink>
          </template>

          <RouterLink
            to="/user"
            :class="[isActiveLink('/user') ? 'bg-green-900' : 'hover:bg-gray-900 hover:text-white',
              'text-white px-3 py-2 rounded-md']">
            My Account
          </RouterLink>

          <button @click="handleLogout" class="text-white px-3 py-2 rounded-md hover:bg-red-700">
            Logout
          </button>

          <span class="text-white px-3 py-2 bg-green-800 rounded-md whitespace-nowrap">
            Welcome, {{ username }}
          </span>
        </div>

        <!-- Mobile: welcome + hamburger -->
        <div v-if="isLoggedIn" class="flex md:hidden items-center gap-2">
          <span class="text-white text-sm bg-green-800 px-2 py-1 rounded-md truncate max-w-[120px]">
            {{ username }}
          </span>
          <button
            @click="menuOpen = !menuOpen"
            class="text-white p-2 rounded-md hover:bg-green-900 focus:outline-none">
            <i :class="menuOpen ? 'pi pi-times' : 'pi pi-bars'" class="text-xl"></i>
          </button>
        </div>

      </div>
    </div>

    <!-- Mobile dropdown menu -->
    <div v-if="isLoggedIn && menuOpen" class="md:hidden bg-green-800 px-4 pb-4 space-y-1">
      <RouterLink
        to="/"
        :class="[isActiveLink('/') ? 'bg-green-900' : 'hover:bg-gray-900',
          'block text-white px-3 py-2 rounded-md']">
        Home
      </RouterLink>

      <RouterLink
        v-if="hasRole('USER') || hasRole('ADMIN')"
        to="/removemac-table"
        :class="[isRemoveMacActive() ? 'bg-green-900' : 'hover:bg-gray-900',
          'block text-white px-3 py-2 rounded-md']">
        Remove mac
      </RouterLink>

      <template v-if="canAccessAdminRoutes()">
        <RouterLink
          to="/users/allusers"
          :class="[isActiveLink('/users/allusers') ? 'bg-green-900' : 'hover:bg-gray-900',
            'block text-white px-3 py-2 rounded-md']">
          All Users
        </RouterLink>

        <RouterLink
          to="/users/add"
          :class="[isActiveLink('/users/add') ? 'bg-green-900' : 'hover:bg-gray-900',
            'block text-white px-3 py-2 rounded-md']">
          Add User
        </RouterLink>

        <RouterLink
          to="/history"
          :class="[isActiveLink('/history') ? 'bg-green-900' : 'hover:bg-gray-900',
            'block text-white px-3 py-2 rounded-md']">
          Deletion History
        </RouterLink>
      </template>

      <RouterLink
        to="/user"
        :class="[isActiveLink('/user') ? 'bg-green-900' : 'hover:bg-gray-900',
          'block text-white px-3 py-2 rounded-md']">
        My Account
      </RouterLink>

      <button
        @click="handleLogout"
        class="block w-full text-left text-white px-3 py-2 rounded-md hover:bg-red-700">
        Logout
      </button>
    </div>
  </nav>
</template>
