import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "form",
    "progressBar",
    "progressText",
    "answeredCount",
    "submitBtn",
    "saveBtn",
    "timer",
    "question"
  ]

  static values = {
    totalQuestions: Number,
    timeLimit: Number,
    remainingTime: Number,
    quizId: Number
  }

  connect() {
    console.log("Quiz controller connected")
    this.updateProgress()
    this.setupEventListeners()

    if (this.timeLimitValue > 0 && this.remainingTimeValue > 0) {
      this.startTimer()
    }
  }

  disconnect() {
    if (this.timerInterval) {
      clearInterval(this.timerInterval)
    }
  }

  setupEventListeners() {
    // Listen for answer changes
    this.element.addEventListener('change', this.handleAnswerChange.bind(this))
    this.element.addEventListener('input', this.handleAnswerChange.bind(this))

    // Auto-save functionality
    this.setupAutoSave()
  }

  handleAnswerChange(event) {
    // Update visual feedback for the question
    const questionBlock = event.target.closest('.question-block')
    if (questionBlock) {
      this.updateQuestionStatus(questionBlock)
    }

    // Update overall progress
    this.updateProgress()

    // Mark form as dirty for auto-save
    this.markFormDirty()
  }

  updateQuestionStatus(questionBlock) {
    const questionId = questionBlock.dataset.questionId
    const inputs = questionBlock.querySelectorAll('input[type="radio"]:checked, textarea:not(:placeholder-shown)')
    const statusElement = questionBlock.querySelector('.inline-flex.items-center')

    if (inputs.length > 0 && (inputs[0].type === 'radio' || inputs[0].value.trim() !== '')) {
      // Question is answered
      statusElement.innerHTML = `
        <svg class="w-4 h-4 mr-1 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
        </svg>
        <span class="text-green-600">Answered</span>
      `

      // Add visual feedback to the question block
      questionBlock.classList.add('border-l-4', 'border-green-400', 'bg-green-50')
      questionBlock.classList.remove('border-l-4', 'border-gray-200')
    } else {
      // Question is not answered
      statusElement.innerHTML = `
        <svg class="w-4 h-4 mr-1 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>
        </svg>
        <span class="text-gray-400">Not answered</span>
      `

      // Remove answered styling
      questionBlock.classList.remove('border-l-4', 'border-green-400', 'bg-green-50')
    }
  }

  updateProgress() {
    const answeredQuestions = this.getAnsweredQuestionCount()
    const percentage = (answeredQuestions / this.totalQuestionsValue) * 100

    // Update progress bar
    if (this.hasProgressBarTarget) {
      this.progressBarTarget.style.width = `${percentage}%`
    }

    // Update progress text
    if (this.hasProgressTextTarget) {
      this.progressTextTarget.textContent = `${answeredQuestions} of ${this.totalQuestionsValue} questions answered`
    }

    // Update answered count
    if (this.hasAnsweredCountTarget) {
      this.answeredCountTarget.textContent = answeredQuestions
    }

    // Update submit button
    this.updateSubmitButton(answeredQuestions)
  }

  getAnsweredQuestionCount() {
    let count = 0

    // Count radio button questions (multiple choice and true/false)
    const radioGroups = new Set()
    this.element.querySelectorAll('input[type="radio"]:checked').forEach(radio => {
      radioGroups.add(radio.name)
    })
    count += radioGroups.size

    // Count textarea questions (short answer)
    this.element.querySelectorAll('textarea').forEach(textarea => {
      if (textarea.value.trim() !== '') {
        count++
      }
    })

    return count
  }

  updateSubmitButton(answeredQuestions) {
    if (!this.hasSubmitBtnTarget) return

    const allAnswered = answeredQuestions === this.totalQuestionsValue
    const unansweredCount = this.totalQuestionsValue - answeredQuestions

    if (allAnswered) {
      this.submitBtnTarget.textContent = 'Submit Quiz'
      this.submitBtnTarget.classList.remove('bg-gray-400')
      this.submitBtnTarget.classList.add('bg-blue-600', 'hover:bg-blue-700')
    } else {
      this.submitBtnTarget.textContent = `Submit Quiz (${unansweredCount} unanswered)`
      // Still allow submission, but with warning
      this.submitBtnTarget.classList.remove('bg-gray-400')
      this.submitBtnTarget.classList.add('bg-orange-600', 'hover:bg-orange-700')
    }
  }

  startTimer() {
    let remainingMinutes = this.remainingTimeValue

    this.timerInterval = setInterval(() => {
      if (remainingMinutes > 0) {
        const hours = Math.floor(remainingMinutes / 60)
        const minutes = remainingMinutes % 60

        if (this.hasTimerTarget) {
          if (hours > 0) {
            this.timerTarget.textContent = `${hours}h ${minutes}m`
          } else {
            this.timerTarget.textContent = `${minutes}m`

            // Warning when under 5 minutes
            if (remainingMinutes <= 5) {
              this.showTimeWarning()
            }
          }
        }

        remainingMinutes--
      } else {
        // Time's up!
        this.handleTimeUp()
      }
    }, 60000) // Update every minute
  }

  showTimeWarning() {
    if (!this.hasTimerTarget) return

    const timerContainer = this.timerTarget.closest('.bg-yellow-50')
    if (timerContainer) {
      timerContainer.classList.remove('bg-yellow-50', 'border-yellow-200')
      timerContainer.classList.add('bg-red-50', 'border-red-200')

      this.timerTarget.classList.remove('text-yellow-900')
      this.timerTarget.classList.add('text-red-900')

      // Show warning notification
      this.showNotification('⚠️ Less than 5 minutes remaining!', 'warning')
    }
  }

  handleTimeUp() {
    clearInterval(this.timerInterval)

    this.showNotification('⏰ Time is up! Your quiz will be submitted automatically.', 'error')

    setTimeout(() => {
      if (this.hasFormTarget) {
        this.formTarget.submit()
      }
    }, 3000)
  }

  markFormDirty() {
    this.formDirty = true
    this.lastChangeTime = Date.now()
  }

  setupAutoSave() {
    // Auto-save every 2 minutes if there are unsaved changes
    this.autoSaveInterval = setInterval(() => {
      if (this.formDirty && Date.now() - this.lastChangeTime > 30000) { // 30 seconds after last change
        this.autoSave()
      }
    }, 120000) // Check every 2 minutes
  }

  autoSave() {
    if (!this.hasSaveBtnTarget || !this.formDirty) return

    this.saveProgress()
  }

  saveProgress() {
    if (!this.hasSaveBtnTarget) return

    const originalText = this.saveBtnTarget.textContent
    this.saveBtnTarget.textContent = '💾 Saving...'
    this.saveBtnTarget.disabled = true

    // Collect form data
    const formData = new FormData(this.formTarget)

    // Send AJAX request to save progress (you'll need to implement the endpoint)
    fetch(`/quizzes/${this.quizIdValue}/save_progress`, {
      method: 'PATCH',
      body: formData,
      headers: {
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').getAttribute('content')
      }
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        this.saveBtnTarget.textContent = '💾 Saved'
        this.formDirty = false
        this.showNotification('✅ Progress saved automatically', 'success')
      } else {
        this.saveBtnTarget.textContent = '💾 Save Failed'
        this.showNotification('❌ Failed to save progress', 'error')
      }
    })
    .catch(error => {
      console.error('Auto-save error:', error)
      this.saveBtnTarget.textContent = '💾 Save Failed'
      this.showNotification('❌ Failed to save progress', 'error')
    })
    .finally(() => {
      setTimeout(() => {
        this.saveBtnTarget.textContent = originalText
        this.saveBtnTarget.disabled = false
      }, 2000)
    })
  }

  // Manual save button click
  save(event) {
    event.preventDefault()
    this.saveProgress()
  }

  showNotification(message, type = 'info') {
    // Create notification element
    const notification = document.createElement('div')
    notification.className = `fixed top-4 right-4 z-50 p-4 rounded-lg shadow-lg transition-all duration-300 transform translate-x-full`

    // Set styles based on type
    switch (type) {
      case 'success':
        notification.classList.add('bg-green-100', 'border', 'border-green-400', 'text-green-700')
        break
      case 'warning':
        notification.classList.add('bg-yellow-100', 'border', 'border-yellow-400', 'text-yellow-700')
        break
      case 'error':
        notification.classList.add('bg-red-100', 'border', 'border-red-400', 'text-red-700')
        break
      default:
        notification.classList.add('bg-blue-100', 'border', 'border-blue-400', 'text-blue-700')
    }

    notification.innerHTML = `
      <div class="flex items-center">
        <span class="flex-1">${message}</span>
        <button class="ml-2 text-gray-400 hover:text-gray-600" onclick="this.parentElement.parentElement.remove()">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
        </button>
      </div>
    `

    document.body.appendChild(notification)

    // Animate in
    setTimeout(() => {
      notification.classList.remove('translate-x-full')
    }, 100)

    // Auto-remove after 5 seconds
    setTimeout(() => {
      notification.classList.add('translate-x-full')
      setTimeout(() => {
        if (notification.parentElement) {
          notification.remove()
        }
      }, 300)
    }, 5000)
  }

  // Keyboard shortcuts
  handleKeydown(event) {
    // Ctrl/Cmd + S to save
    if ((event.ctrlKey || event.metaKey) && event.key === 's') {
      event.preventDefault()
      this.saveProgress()
    }

    // Ctrl/Cmd + Enter to submit (if all questions answered)
    if ((event.ctrlKey || event.metaKey) && event.key === 'Enter') {
      const answeredQuestions = this.getAnsweredQuestionCount()
      if (answeredQuestions === this.totalQuestionsValue && this.hasSubmitBtnTarget) {
        event.preventDefault()
        this.submitBtnTarget.click()
      }
    }
  }
}
