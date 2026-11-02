<script setup>
import { computed } from 'vue'
import { STATUS, lateDays, isHeld } from '../store.js'
import { plural } from '../format.js'
const props = defineProps({ order: Object, plain: Boolean })
const late = computed(() => (props.plain ? 0 : lateDays(props.order)))
const held = computed(() => !props.plain && isHeld(props.order))
const st = computed(() => STATUS[props.order.status])
</script>
<template>
  <span class="status" :class="{ 'status--late': late }">
    <span class="dot" :class="'dot--' + (late ? 'danger' : held ? 'held' : st.dot)" aria-hidden="true"></span>
    <span>{{ late ? `Atrasada ${plural(late, 'dia', 'dias')}` : held ? 'Parada' : st.label }}</span>
  </span>
</template>
