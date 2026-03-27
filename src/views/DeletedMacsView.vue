<script setup>
import { reactive, ref, watch, onMounted } from 'vue';
import { useToast } from 'vue-toastification';
import PulseLoader from 'vue-spinner/src/PulseLoader.vue';
import api from '@/api/index';

const toast = useToast();

const PAGE_SIZE_OPTIONS = [50, 100, 200, 400];

const state = reactive({
    records: [],
    isLoading: true,
    totalElements: 0,
    totalPages: 0,
    currentPage: 0,
    pageSize: 50
});

// Filters
const filterMac = ref('');
const filterUserId = ref(null);  // null = any, 0 = System, N = user id
const filterReason = ref('');
const filterDateFrom = ref('');
const filterDateTo = ref('');

// Users list for dropdown
const users = ref([]);

const loadUsers = async () => {
    try {
        const response = await api.adminUsers.getAll();
        users.value = response.data;
    } catch {
        // silently ignore — filter will still work without dropdown
    }
};

let debounceTimeout = null;
const triggerFetch = () => {
    clearTimeout(debounceTimeout);
    debounceTimeout = setTimeout(() => fetchHistory(0), 400);
};

watch([filterMac, filterUserId, filterReason, filterDateFrom, filterDateTo], triggerFetch);

const fetchHistory = async (page = state.currentPage, size = state.pageSize) => {
    state.isLoading = true;
    try {
        const response = await api.deletedMacs.getAll({
            page,
            size,
            mac: filterMac.value.trim() || undefined,
            userId: filterUserId.value !== null ? filterUserId.value : undefined,
            reason: filterReason.value.trim() || undefined,
            dateFrom: filterDateFrom.value || undefined,
            dateTo: filterDateTo.value || undefined,
        });
        const data = response.data;
        state.records = data.content;
        state.totalElements = data.page.totalElements;
        state.totalPages = data.page.totalPages;
        state.currentPage = data.page.number;
    } catch (error) {
        toast.error('Failed to load deletion history');
    } finally {
        state.isLoading = false;
    }
};

const goToPage = (page) => {
    if (page < 0 || page >= state.totalPages) return;
    fetchHistory(page, state.pageSize);
};

const onPageSizeChange = (size) => {
    state.pageSize = size;
    fetchHistory(0, size);
};

const resetFilters = () => {
    filterMac.value = '';
    filterUserId.value = null;
    filterReason.value = '';
    filterDateFrom.value = '';
    filterDateTo.value = '';
};

const hasActiveFilters = () =>
    filterMac.value || filterUserId.value !== null || filterReason.value || filterDateFrom.value || filterDateTo.value;

const formatDateTime = (dt) => {
    if (!dt) return '—';
    return new Date(dt).toLocaleString('en-GB', {
        year: 'numeric', month: '2-digit', day: '2-digit',
        hour: '2-digit', minute: '2-digit', second: '2-digit'
    });
};

onMounted(async () => {
    await loadUsers();
    fetchHistory(0);
});
</script>

<template>
    <section class="bg-blue-50 min-h-screen px-4 py-10">
        <div class="container-xl lg:container m-auto">

            <!-- Header -->
            <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between mb-6 gap-4">
                <h2 class="text-3xl font-bold text-green-500">MAC Deletion History</h2>
                <button
                    @click="fetchHistory(0)"
                    class="inline-flex items-center gap-2 border border-gray-300 hover:bg-gray-100 text-gray-700 font-medium py-2 px-4 rounded-lg transition-colors">
                    <i class="pi pi-refresh"></i>
                    Refresh
                </button>
            </div>

            <!-- Filters -->
            <div class="bg-white rounded-xl shadow-sm border border-gray-200 px-4 py-3 mb-4">
                <div class="flex flex-wrap items-end gap-3">
                    <div class="flex flex-col gap-1">
                        <label class="text-xs font-medium text-gray-500 uppercase tracking-wide">MAC</label>
                        <input
                            v-model="filterMac"
                            type="text"
                            placeholder="AA:BB:CC..."
                            class="border border-gray-300 rounded-lg py-2 px-3 text-sm focus:outline-none focus:ring-2 focus:ring-green-400 w-40"
                        />
                    </div>

                    <div class="flex flex-col gap-1">
                        <label class="text-xs font-medium text-gray-500 uppercase tracking-wide">Deleted By</label>
                        <select
                            v-model="filterUserId"
                            class="border border-gray-300 rounded-lg py-2 px-3 text-sm focus:outline-none focus:ring-2 focus:ring-green-400 bg-white w-44">
                            <option :value="null">— Any user —</option>
                            <option :value="0">System</option>
                            <option
                                v-for="u in users"
                                :key="u.id"
                                :value="u.id"
                                :class="!u.enabled ? 'text-gray-400' : ''">
                                {{ u.name }}{{ !u.enabled ? ' (disabled)' : '' }}
                            </option>
                        </select>
                    </div>

                    <div class="flex flex-col gap-1">
                        <label class="text-xs font-medium text-gray-500 uppercase tracking-wide">Reason</label>
                        <input
                            v-model="filterReason"
                            type="text"
                            placeholder="Search reason..."
                            class="border border-gray-300 rounded-lg py-2 px-3 text-sm focus:outline-none focus:ring-2 focus:ring-green-400 w-40"
                        />
                    </div>

                    <div class="flex flex-col gap-1">
                        <label class="text-xs font-medium text-gray-500 uppercase tracking-wide">From</label>
                        <input
                            v-model="filterDateFrom"
                            type="date"
                            :max="filterDateTo || undefined"
                            class="border border-gray-300 rounded-lg py-2 px-3 text-sm focus:outline-none focus:ring-2 focus:ring-green-400"
                        />
                    </div>

                    <div class="flex flex-col gap-1">
                        <label class="text-xs font-medium text-gray-500 uppercase tracking-wide">To</label>
                        <input
                            v-model="filterDateTo"
                            type="date"
                            :min="filterDateFrom || undefined"
                            class="border border-gray-300 rounded-lg py-2 px-3 text-sm focus:outline-none focus:ring-2 focus:ring-green-400"
                        />
                    </div>

                    <button
                        v-if="hasActiveFilters()"
                        @click="resetFilters"
                        class="inline-flex items-center gap-1.5 px-3 py-2 rounded-lg border border-gray-300 text-sm text-gray-500 hover:bg-gray-50 transition-colors">
                        <i class="pi pi-times text-xs"></i>
                        Clear
                    </button>
                </div>
            </div>

            <!-- Per page + page size -->
            <div class="flex items-center gap-2 mb-4">
                <span class="text-sm text-gray-500 whitespace-nowrap">Per page:</span>
                <div class="flex gap-1">
                    <button
                        v-for="opt in PAGE_SIZE_OPTIONS"
                        :key="opt"
                        @click="onPageSizeChange(opt)"
                        :class="[
                            'px-3 py-1.5 rounded-lg text-sm font-medium border transition-colors',
                            state.pageSize === opt
                                ? 'bg-green-500 text-white border-green-500'
                                : 'bg-white text-gray-600 border-gray-300 hover:bg-gray-50'
                        ]">
                        {{ opt }}
                    </button>
                </div>
            </div>

            <!-- Loading -->
            <div v-if="state.isLoading" class="text-center py-12">
                <PulseLoader />
            </div>

            <template v-else>
                <!-- Pagination TOP -->
                <div class="flex items-center justify-between mb-3">
                    <span class="text-sm text-gray-500">
                        {{ state.totalElements }} record(s)
                        &mdash; page {{ state.currentPage + 1 }} of {{ state.totalPages }}
                    </span>
                    <div v-if="state.totalPages > 1" class="flex gap-2">
                        <button
                            @click="goToPage(state.currentPage - 1)"
                            :disabled="state.currentPage === 0"
                            class="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg border text-sm font-medium transition-colors
                                   bg-white border-gray-300 text-gray-600 hover:bg-gray-50
                                   disabled:opacity-40 disabled:cursor-not-allowed">
                            <i class="pi pi-chevron-left text-xs"></i>
                            Prev
                        </button>
                        <button
                            @click="goToPage(state.currentPage + 1)"
                            :disabled="state.currentPage >= state.totalPages - 1"
                            class="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg border text-sm font-medium transition-colors
                                   bg-white border-gray-300 text-gray-600 hover:bg-gray-50
                                   disabled:opacity-40 disabled:cursor-not-allowed">
                            Next
                            <i class="pi pi-chevron-right text-xs"></i>
                        </button>
                    </div>
                </div>

                <!-- Table -->
                <div class="bg-white rounded-xl shadow-md overflow-x-auto">
                    <table class="min-w-full divide-y divide-gray-200">
                        <thead class="bg-gray-50">
                            <tr>
                                <th class="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">MAC Address</th>
                                <th class="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Deleted At</th>
                                <th class="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Deleted By</th>
                                <th class="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Reason</th>
                                <th class="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">Original Block Time</th>
                                <th class="px-4 py-3 text-left text-xs font-semibold text-gray-500 uppercase tracking-wider">WLC</th>
                            </tr>
                        </thead>
                        <tbody class="divide-y divide-gray-100">
                            <tr v-if="state.records.length === 0">
                                <td colspan="6" class="text-center py-8 text-gray-400">No records found</td>
                            </tr>
                            <tr
                                v-for="record in state.records"
                                :key="record.id"
                                class="hover:bg-gray-50 transition-colors">
                                <td class="px-4 py-3 font-mono text-sm text-gray-900">{{ record.clientMac }}</td>
                                <td class="px-4 py-3 text-sm text-gray-600 whitespace-nowrap">{{ formatDateTime(record.deletedTime) }}</td>
                                <td class="px-4 py-3 text-sm">
                                    <span
                                        :class="[
                                            'inline-block text-xs font-medium px-2.5 py-1 rounded-full',
                                            record.deletedByUserId === null
                                                ? 'bg-gray-100 text-gray-500'
                                                : 'bg-blue-100 text-blue-700'
                                        ]">
                                        {{ record.deletedByUserName }}
                                    </span>
                                </td>
                                <td class="px-4 py-3 text-sm text-gray-600">{{ record.reason }}</td>
                                <td class="px-4 py-3 text-sm text-gray-500">{{ record.originalBlockTime }}</td>
                                <td class="px-4 py-3 text-sm text-gray-500">{{ record.wlcId }}</td>
                            </tr>
                        </tbody>
                    </table>
                </div>

                <!-- Pagination BOTTOM -->
                <div v-if="state.totalPages > 1" class="flex items-center justify-between mt-3">
                    <div class="flex items-center gap-2">
                        <span class="text-sm text-gray-500 whitespace-nowrap">Per page:</span>
                        <div class="flex gap-1">
                            <button
                                v-for="opt in PAGE_SIZE_OPTIONS"
                                :key="opt"
                                @click="onPageSizeChange(opt)"
                                :class="[
                                    'px-3 py-1.5 rounded-lg text-sm font-medium border transition-colors',
                                    state.pageSize === opt
                                        ? 'bg-green-500 text-white border-green-500'
                                        : 'bg-white text-gray-600 border-gray-300 hover:bg-gray-50'
                                ]">
                                {{ opt }}
                            </button>
                        </div>
                    </div>
                    <div class="flex gap-2">
                        <button
                            @click="goToPage(state.currentPage - 1)"
                            :disabled="state.currentPage === 0"
                            class="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg border text-sm font-medium transition-colors
                                   bg-white border-gray-300 text-gray-600 hover:bg-gray-50
                                   disabled:opacity-40 disabled:cursor-not-allowed">
                            <i class="pi pi-chevron-left text-xs"></i>
                            Prev
                        </button>
                        <button
                            @click="goToPage(state.currentPage + 1)"
                            :disabled="state.currentPage >= state.totalPages - 1"
                            class="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg border text-sm font-medium transition-colors
                                   bg-white border-gray-300 text-gray-600 hover:bg-gray-50
                                   disabled:opacity-40 disabled:cursor-not-allowed">
                            Next
                            <i class="pi pi-chevron-right text-xs"></i>
                        </button>
                    </div>
                </div>
            </template>
        </div>
    </section>
</template>
