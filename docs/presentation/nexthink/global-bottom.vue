<script setup lang="ts">
import { computed } from 'vue'
import { useNav } from '@slidev/client'
const { currentPage, total, isPresenter } = useNav()
// The PDF export renders every slide on /presenter/print: no fixed bar there
const isPrint = typeof location !== 'undefined' && location.pathname.includes('/print')
const progress = computed(() => `${(currentPage.value / total.value) * 100}%`)
</script>

<template>
  <!-- The presenter view has its own progress bar, so only show ours on the audience view -->
  <Teleport v-if="!isPresenter && !isPrint" to="body">
    <div class="progress-track">
      <div class="progress-fill" :style="{ width: progress }" />
    </div>
  </Teleport>
  <div v-show="currentPage > 1" class="slide-number">{{ currentPage }}/{{ total }}</div>
</template>
