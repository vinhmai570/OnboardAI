import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "moduleModal", "stepModal", "moduleForm", "stepForm",
    "moduleTitle", "moduleDescription", "moduleDuration",
    "stepTitle", "stepType", "stepDuration", "stepContent",
    "moduleModalTitle", "stepModalTitle"
  ]

  static values = {
    courseId: String,
    editingModuleId: String,
    editingStepId: String,
    editingModuleContext: String
  }

  connect() {
    console.log("Course structure controller connected")
    this.initializeSortable()
  }

  // Initialize drag & drop functionality
  initializeSortable() {
    if (typeof Sortable !== 'undefined') {
      // Initialize Sortable for modules
      const modulesContainer = document.getElementById('modules-container')
      if (modulesContainer) {
        new Sortable(modulesContainer, {
          handle: '.drag-handle',
          animation: 150,
          ghostClass: 'opacity-50',
          chosenClass: 'ring-2 ring-blue-400',
          onEnd: (evt) => {
            this.updateModuleOrder()
          }
        })
      }

      // Initialize Sortable for each step container
      document.querySelectorAll('.steps-container').forEach(container => {
        new Sortable(container, {
          handle: '.drag-handle-step',
          animation: 150,
          ghostClass: 'opacity-50',
          chosenClass: 'ring-2 ring-blue-400',
          filter: '.mt-2', // Exclude the "Add Step" button div
          onEnd: (evt) => {
            this.updateStepOrder(container.dataset.moduleId)
          }
        })
      })
    }
  }

  // Module actions
  addModule(event) {
    event.preventDefault()
    this.editingModuleIdValue = ""
    this.moduleModalTitleTarget.textContent = 'Add Module'
    this.moduleTitleTarget.value = ''
    this.moduleDescriptionTarget.value = ''
    this.moduleDurationTarget.value = '1'
    this.showModal(this.moduleModalTarget)
  }

  editModule(event) {
    event.preventDefault()
    const button = event.currentTarget
    this.editingModuleIdValue = button.dataset.moduleId
    this.moduleModalTitleTarget.textContent = 'Edit Module'
    this.moduleTitleTarget.value = button.dataset.title || ''
    this.moduleDescriptionTarget.value = button.dataset.description || ''
    this.moduleDurationTarget.value = button.dataset.duration || '1'
    this.showModal(this.moduleModalTarget)
  }

  async deleteModule(event) {
    event.preventDefault()
    if (confirm('Are you sure you want to delete this module and all its steps?')) {
      const moduleId = event.currentTarget.dataset.moduleId
      await this.apiDeleteModule(moduleId)
    }
  }

  // Step actions
  addStep(event) {
    event.preventDefault()
    this.editingStepIdValue = ""
    this.editingModuleContextValue = event.currentTarget.dataset.moduleId
    this.stepModalTitleTarget.textContent = 'Add Step'
    this.stepTitleTarget.value = ''
    this.stepTypeTarget.value = 'lesson'
    this.stepDurationTarget.value = '30'
    this.stepContentTarget.value = ''
    this.showModal(this.stepModalTarget)
  }

  editStep(event) {
    event.preventDefault()
    const button = event.currentTarget
    this.editingStepIdValue = button.dataset.stepId
    this.editingModuleContextValue = button.dataset.moduleId
    this.stepModalTitleTarget.textContent = 'Edit Step'
    this.stepTitleTarget.value = button.dataset.title || ''
    this.stepTypeTarget.value = button.dataset.type || 'lesson'
    this.stepDurationTarget.value = button.dataset.duration || '30'
    this.stepContentTarget.value = button.dataset.content || ''
    this.showModal(this.stepModalTarget)
  }

  async deleteStep(event) {
    event.preventDefault()
    if (confirm('Are you sure you want to delete this step?')) {
      const button = event.currentTarget
      const moduleId = button.dataset.moduleId
      const stepId = button.dataset.stepId
      await this.apiDeleteStep(moduleId, stepId)
    }
  }

  // Form submissions
  async submitModuleForm(event) {
    event.preventDefault()
    const title = this.moduleTitleTarget.value
    const description = this.moduleDescriptionTarget.value
    const duration = this.moduleDurationTarget.value

    if (this.editingModuleIdValue) {
      await this.apiEditModule(this.editingModuleIdValue, title, description, duration)
    } else {
      await this.apiAddModule(title, description, duration)
    }
    this.hideModal(this.moduleModalTarget)
  }

  async submitStepForm(event) {
    event.preventDefault()
    const title = this.stepTitleTarget.value
    const type = this.stepTypeTarget.value
    const duration = this.stepDurationTarget.value
    const content = this.stepContentTarget.value

    if (this.editingStepIdValue) {
      await this.apiEditStep(this.editingModuleContextValue, this.editingStepIdValue, title, type, duration, content)
    } else {
      await this.apiAddStep(this.editingModuleContextValue, title, type, duration, content)
    }
    this.hideModal(this.stepModalTarget)
  }

  // Modal management
  cancelModule(event) {
    event.preventDefault()
    this.hideModal(this.moduleModalTarget)
  }

  cancelStep(event) {
    event.preventDefault()
    this.hideModal(this.stepModalTarget)
  }

  showModal(modal) {
    console.log('showModal called with:', modal)
    console.log('Modal display before:', modal.style.display)
    modal.style.display = 'flex'
    console.log('Modal display after:', modal.style.display)
    console.log('Modal should now be visible with inline style')
  }

  hideModal(modal) {
    console.log('hideModal called with:', modal)
    modal.style.display = 'none'
  }

  showNotification(message, type = 'success') {
    const notification = document.createElement('div')
    notification.className = `fixed top-4 right-4 px-4 py-2 rounded-lg text-white z-50 ${type === 'success' ? 'bg-green-600' : 'bg-red-600'}`
    notification.textContent = message
    document.body.appendChild(notification)

    setTimeout(() => {
      notification.remove()
    }, 3000)
  }

  // API functions
  async apiCall(url, method, data = {}) {
    try {
      const response = await fetch(url, {
        method: method,
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: method !== 'GET' ? JSON.stringify(data) : null
      })
      return await response.json()
    } catch (error) {
      console.error('API call failed:', error)
      this.showNotification('Operation failed. Please try again.', 'error')
      return { success: false, error: error.message }
    }
  }

  async apiAddModule(title, description, duration) {
    const result = await this.apiCall(`/admin/courses/${this.courseIdValue}/course_modules.json`, 'POST', {
      course_module: { title, description, duration_hours: duration }
    })
    if (result.success) {
      this.showNotification('Module added successfully!')
      location.reload()
    } else {
      this.showNotification('Failed to add module.', 'error')
    }
  }

  async apiEditModule(moduleId, title, description, duration) {
    const result = await this.apiCall(`/admin/courses/${this.courseIdValue}/course_modules/${moduleId}.json`, 'PUT', {
      course_module: { title, description, duration_hours: duration }
    })
    if (result.success) {
      this.showNotification('Module updated successfully!')
      location.reload()
    } else {
      this.showNotification('Failed to update module.', 'error')
    }
  }

  async apiDeleteModule(moduleId) {
    const result = await this.apiCall(`/admin/courses/${this.courseIdValue}/course_modules/${moduleId}.json`, 'DELETE')
    if (result.success) {
      this.showNotification('Module deleted successfully!')
      location.reload()
    } else {
      this.showNotification('Failed to delete module.', 'error')
    }
  }

  async apiAddStep(moduleId, title, type, duration, content) {
    const result = await this.apiCall(`/admin/courses/${this.courseIdValue}/course_modules/${moduleId}/course_steps.json`, 'POST', {
      course_step: { title, step_type: type, duration_minutes: duration, content }
    })
    if (result.success) {
      this.showNotification('Step added successfully!')
      location.reload()
    } else {
      this.showNotification('Failed to add step.', 'error')
    }
  }

  async apiEditStep(moduleId, stepId, title, type, duration, content) {
    const result = await this.apiCall(`/admin/courses/${this.courseIdValue}/course_modules/${moduleId}/course_steps/${stepId}.json`, 'PUT', {
      course_step: { title, step_type: type, duration_minutes: duration, content }
    })
    if (result.success) {
      this.showNotification('Step updated successfully!')
      location.reload()
    } else {
      this.showNotification('Failed to update step.', 'error')
    }
  }

  async apiDeleteStep(moduleId, stepId) {
    const result = await this.apiCall(`/admin/courses/${this.courseIdValue}/course_modules/${moduleId}/course_steps/${stepId}.json`, 'DELETE')
    if (result.success) {
      this.showNotification('Step deleted successfully!')
      location.reload()
    } else {
      this.showNotification('Failed to delete step.', 'error')
    }
  }

  async updateModuleOrder() {
    // Implementation for drag & drop reordering can be added here if needed
    console.log('Module order updated')
  }

  async updateStepOrder(moduleId) {
    // Implementation for drag & drop reordering can be added here if needed
    console.log('Step order updated for module', moduleId)
  }
}
