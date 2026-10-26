<script setup lang="ts">
import { useNav } from '@slidev/client'
const { currentPage, total } = useNav()
</script>

<template>
  <div v-show="currentPage > 1" class="slide-number">{{ currentPage }}/{{ total }}</div>
</template>
