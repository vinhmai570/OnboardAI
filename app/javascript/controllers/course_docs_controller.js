import { Controller } from "@hotwired/stimulus"
import { marked } from "marked"

// Connects to data-controller="course-docs"
export default class extends Controller {
  static targets = [
    "leftSidebar", "rightSidebar", "mainContent", "welcomeState", "stepContent",
    "moduleNav", "moduleToggle", "moduleIcon", "moduleSteps", "stepButton",
    "stepHeader", "stepTitle", "stepMeta", "stepBody", "breadcrumbs",
    "stepNavigation", "prevButton", "nextButton",
    "chatMessages", "chatInput", "chatForm"
  ]

  static values = { courseId: Number }

  connect() {
    console.log("Course docs controller connected")
    console.log("hasLeftSidebarTarget:", this.hasLeftSidebarTarget)
    console.log("hasRightSidebarTarget:", this.hasRightSidebarTarget)
    console.log("hasModuleNavTarget:", this.hasModuleNavTarget)

    // Store current step and module data
    this.currentStepId = null
    this.currentModuleId = null
    this.coursesSteps = []
    this.courseModules = []

    // Initialize the interface
    this.loadCourseData()

    // Set up marked for markdown rendering
    marked.setOptions({
      breaks: true,
      gfm: true
    })
  }

  // Load course data from the DOM
  loadCourseData() {
    const moduleButtons = this.moduleToggleTargets
    const stepButtons = this.stepButtonTargets

    // Extract course structure from DOM
    this.courseModules = moduleButtons.map(btn => {
      const moduleId = parseInt(btn.dataset.moduleId)
      const moduleSteps = stepButtons.filter(stepBtn =>
        parseInt(stepBtn.dataset.moduleId) === moduleId
      ).map(stepBtn => ({
        id: parseInt(stepBtn.dataset.stepId),
        moduleId: moduleId,
        element: stepBtn
      }))

      return {
        id: moduleId,
        element: btn,
        steps: moduleSteps
      }
    })

    // Flatten steps for easy navigation
    this.courseSteps = this.courseModules.flatMap(module => module.steps)

    console.log("Loaded course data:", this.courseModules.length, "modules,", this.courseSteps.length, "steps")
  }

  // Toggle left sidebar on mobile
  toggleLeftSidebar() {
    if (this.hasLeftSidebarTarget) {
      this.leftSidebarTarget.classList.toggle("hidden")
    }
  }

  // Toggle right sidebar (AI chat)
  toggleRightSidebar() {
    if (this.hasRightSidebarTarget) {
      this.rightSidebarTarget.classList.toggle("hidden")
    }
  }

  // Toggle module expansion/collapse
  toggleModule(event) {
    const moduleId = event.currentTarget.dataset.moduleId
    const moduleIcon = event.currentTarget.querySelector('[data-course-docs-target="moduleIcon"]')
    const moduleSteps = this.moduleStepsTargets.find(steps =>
      steps.dataset.moduleId === moduleId
    )

    if (moduleSteps && moduleIcon) {
      const isExpanded = !moduleSteps.classList.contains("hidden")

      if (isExpanded) {
        // Collapse
        moduleSteps.classList.add("hidden")
        moduleIcon.style.transform = "rotate(0deg)"
      } else {
        // Expand
        moduleSteps.classList.remove("hidden")
        moduleIcon.style.transform = "rotate(90deg)"
      }
    }
  }

    // Select and display a step
  selectStep(event) {
    const stepId = parseInt(event.currentTarget.dataset.stepId)
    const moduleId = parseInt(event.currentTarget.dataset.moduleId)
    const stepType = event.currentTarget.dataset.stepType

    console.log("Selecting step:", stepId, "from module:", moduleId, "type:", stepType)

            // Check if this is a quiz/assessment step - load quiz content inline
    if (stepType === 'assessment') {
      console.log("Assessment step detected - loading quiz inline...")

      // Get course and module IDs for the nested route
      const courseId = this.courseIdValue

      // Make an AJAX request to check if this step has a quiz
      fetch(`/admin/courses/${courseId}/course_modules/${moduleId}/course_steps/${stepId}/quiz_check`, {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').getAttribute('content')
        }
      })
      .then(response => response.json())
      .then(data => {
        if (data.has_quiz) {
          // Load quiz content inline instead of redirecting
          this.loadQuizContent(data.quiz_id, stepId, moduleId, event.currentTarget)
        } else {
          // No quiz found, show step content normally
          this.showStepContent(event.currentTarget, stepId, moduleId)
        }
      })
      .catch(error => {
        console.error('Error checking for quiz:', error)
        console.error('Failed URL:', `/admin/courses/${courseId}/course_modules/${moduleId}/course_steps/${stepId}/quiz_check`)
        // Show user-friendly error message
        this.showNotification('Unable to load quiz. Please try again or contact support.', 'error')
        // Fallback to showing step content normally
        this.showStepContent(event.currentTarget, stepId, moduleId)
      })

      return // Early return for assessment steps
    }

    // For non-assessment steps, show content normally
    this.showStepContent(event.currentTarget, stepId, moduleId)
  }

  // Extracted method to show step content normally
  showStepContent(element, stepId, moduleId) {
    // Update active states
    this.updateActiveStep(stepId, moduleId)

    // Load step content from DOM data attributes
    this.loadStepContentFromElement(element)

    // Show step content and hide welcome
    if (this.hasWelcomeStateTarget && this.hasStepContentTarget) {
      this.welcomeStateTarget.classList.add("hidden")
      this.stepContentTarget.classList.remove("hidden")
    }

    // Update navigation buttons
    this.updateStepNavigation(stepId)
  }

  // Active step styling is handled by updateActiveStep method in quiz section

      // Load step content from DOM element data attributes
  loadStepContentFromElement(element) {
    console.log("Loading step content from DOM element")

    // Handle null element case
    if (!element || !element.dataset) {
      console.error("Element or element.dataset is null")
      return
    }

    // Helper to decode HTML entities
    const decodeHtml = (str) => {
      const txt = document.createElement("textarea")
      txt.innerHTML = str
      return txt.value
    }

    // Extract all the step data from data attributes
    const stepData = {
      id: parseInt(element.dataset.stepId),
      title: decodeHtml(element.dataset.stepTitle || ''),
      step_type: element.dataset.stepType,
      content: decodeHtml(element.dataset.stepContent || ''),
      detailed_content: decodeHtml(element.dataset.stepDetailedContent || ''),
      duration_minutes: parseInt(element.dataset.stepDuration),
      module_title: decodeHtml(element.dataset.moduleTitle || ''),
      content_generated: element.dataset.stepGenerated === 'true',
      icon: element.querySelector('.text-lg').textContent.trim()
    }

    console.log("Step data from DOM:", {
      id: stepData.id,
      title: stepData.title,
      hasDetailedContent: !!stepData.detailed_content,
      detailedContentLength: stepData.detailed_content.length,
      detailedContentPreview: stepData.detailed_content.substring(0, 100) + '...'
    })

    this.displayStepContent(stepData)
  }

    // Fallback: load step content from DOM
  loadStepContentFromDOM(stepId, moduleId) {
    console.log("Loading step content from DOM for step:", stepId)

    const stepElement = this.stepButtonTargets.find(btn =>
      parseInt(btn.dataset.stepId) === stepId
    )

    if (stepElement) {
      const stepTitle = stepElement.querySelector('div > div').textContent.trim()
      const stepType = stepElement.querySelector('.text-xs').textContent.split('•')[0].trim()

      // Get module info
      const moduleElement = this.moduleToggleTargets.find(btn =>
        parseInt(btn.dataset.moduleId) === moduleId
      )
      const moduleTitle = moduleElement ?
        moduleElement.querySelector('.text-sm.font-medium').textContent.trim() :
        `Module ${moduleId}`

      // Try to load step data via a direct database query fallback
      this.loadStepFromDatabase(stepId, {
        id: stepId,
        title: stepTitle,
        step_type: stepType.toLowerCase(),
        module_title: moduleTitle,
        content: "Loading step content...",
        detailed_content: null
      })
    }
  }

  // Direct database fallback - make a simple request to get step content
  async loadStepFromDatabase(stepId, fallbackData) {
    try {
      // Try a simple fetch without complex headers
      const response = await fetch(`/admin/course_generator/step_content/${stepId}`)

      if (response.ok) {
        const text = await response.text()
        try {
          const stepData = JSON.parse(text)
          console.log("Database step data loaded:", stepData)
          this.displayStepContent(stepData)
          return
        } catch (parseError) {
          console.warn("Failed to parse step content JSON:", parseError)
        }
      }
    } catch (error) {
      console.warn("Database fallback failed:", error)
    }

    // Final fallback to basic data
    console.log("Using final fallback data")
    this.displayStepContent(fallbackData)
  }

  // Display step content in main area
  displayStepContent(stepData) {
    // Update breadcrumbs
    if (this.hasBreadcrumbsTarget) {
      this.breadcrumbsTarget.innerHTML = `
        <span class="text-blue-600">${stepData.module_title}</span>
        <span class="mx-2">></span>
        <span>${stepData.title}</span>
      `
    }

    // Update title
    if (this.hasStepTitleTarget) {
      this.stepTitleTarget.textContent = stepData.title
    }

    // Update metadata
    if (this.hasStepMetaTarget) {
      const stepTypeColors = {
        'lesson': 'bg-blue-100 text-blue-800',
        'exercise': 'bg-green-100 text-green-800',
        'reading': 'bg-purple-100 text-purple-800',
        'video': 'bg-yellow-100 text-yellow-800',
        'assessment': 'bg-red-100 text-red-800'
      }

      const colorClass = stepTypeColors[stepData.step_type] || 'bg-gray-100 text-gray-800'

      this.stepMetaTarget.innerHTML = `
        <span class="px-2 py-1 ${colorClass} rounded-full text-xs font-medium">
          ${stepData.step_type.charAt(0).toUpperCase() + stepData.step_type.slice(1)}
        </span>
        <span class="text-gray-600">•</span>
        <span class="text-gray-600">${stepData.duration_minutes || 15} min</span>
        ${stepData.content_generated ? '<span class="text-green-600">• ✓ Generated</span>' : ''}
      `
    }

        // Update content
    if (this.hasStepBodyTarget) {
      let content = ""

      // Prioritize detailed_content from database
      if (stepData.detailed_content && stepData.detailed_content.trim().length > 0) {
        content = stepData.detailed_content
        console.log("Using detailed_content from database:", content.substring(0, 100) + "...")
      } else if (stepData.content && stepData.content.trim().length > 0) {
        content = stepData.content
        console.log("Using basic content:", content.substring(0, 100) + "...")
      } else {
        content = "Content is being generated. Please check back later."
        console.log("No content available, using fallback message")
      }

      // Convert markdown to HTML if it looks like markdown
      if (content && (content.includes('##') || content.includes('*') || content.includes('`') || content.includes('---'))) {
        try {
          content = marked(content)
          console.log("Converted markdown to HTML")
        } catch (error) {
          console.warn("Failed to convert markdown:", error)
          // Fallback to simple formatting
          content = content.replace(/\n\n/g, '</p><p>').replace(/^\s*/, '<p>').replace(/\s*$/, '</p>')
        }
      } else {
        // Simple format for plain text
        content = content.replace(/\n\n/g, '</p><p>').replace(/^\s*/, '<p>').replace(/\s*$/, '</p>')
      }

      this.stepBodyTarget.innerHTML = content
    }
  }

  // Update navigation buttons
  updateStepNavigation(currentStepId) {
    const currentIndex = this.courseSteps.findIndex(step => step.id === currentStepId)

    if (this.hasPrevButtonTarget) {
      if (currentIndex > 0) {
        this.prevButtonTarget.classList.remove("hidden")
        this.prevButtonTarget.dataset.targetStepId = this.courseSteps[currentIndex - 1].id
        this.prevButtonTarget.dataset.targetModuleId = this.courseSteps[currentIndex - 1].moduleId
      } else {
        this.prevButtonTarget.classList.add("hidden")
      }
    }

    if (this.hasNextButtonTarget) {
      if (currentIndex < this.courseSteps.length - 1) {
        this.nextButtonTarget.classList.remove("hidden")
        this.nextButtonTarget.dataset.targetStepId = this.courseSteps[currentIndex + 1].id
        this.nextButtonTarget.dataset.targetModuleId = this.courseSteps[currentIndex + 1].moduleId
      } else {
        this.nextButtonTarget.classList.add("hidden")
      }
    }
  }

  // Navigate to previous step
  previousStep() {
    if (this.hasPrevButtonTarget && !this.prevButtonTarget.classList.contains("hidden")) {
      const stepId = parseInt(this.prevButtonTarget.dataset.targetStepId)
      const moduleId = parseInt(this.prevButtonTarget.dataset.targetModuleId)
      this.selectStepById(stepId, moduleId)
    }
  }

  // Navigate to next step
  nextStep() {
    if (this.hasNextButtonTarget && !this.nextButtonTarget.classList.contains("hidden")) {
      const stepId = parseInt(this.nextButtonTarget.dataset.targetStepId)
      const moduleId = parseInt(this.nextButtonTarget.dataset.targetModuleId)
      this.selectStepById(stepId, moduleId)
    }
  }

    // Helper to select step by ID
  selectStepById(stepId, moduleId) {
    const stepButton = this.stepButtonTargets.find(btn =>
      parseInt(btn.dataset.stepId) === stepId
    )

    if (stepButton) {
      // Ensure module is expanded
      const moduleSteps = this.moduleStepsTargets.find(steps =>
        steps.dataset.moduleId === moduleId.toString()
      )
      if (moduleSteps && moduleSteps.classList.contains("hidden")) {
        const moduleToggle = this.moduleToggleTargets.find(btn =>
          btn.dataset.moduleId === moduleId.toString()
        )
        if (moduleToggle) {
          moduleToggle.click()
        }
      }

      // Trigger step selection using the new DOM-based method
      this.updateActiveStep(stepId, moduleId)
      this.loadStepContentFromElement(stepButton)

      // Show step content and hide welcome
      if (this.hasWelcomeStateTarget && this.hasStepContentTarget) {
        this.welcomeStateTarget.classList.add("hidden")
        this.stepContentTarget.classList.remove("hidden")
      }

      // Update navigation buttons
      this.updateStepNavigation(stepId)

      // Scroll step into view
      stepButton.scrollIntoView({ behavior: 'smooth', block: 'center' })
    }
  }

  // Handle AI chat form submission
  async sendChatMessage(event) {
    event.preventDefault()

    const message = this.chatInputTarget.value.trim()
    if (!message) return

    // Add user message to chat
    this.addChatMessage('user', message)

    // Clear input
    this.chatInputTarget.value = ''

    // Add loading message
    const loadingId = this.addChatMessage('ai', 'Thinking...', true)

    try {
      // Build context from current step
      const context = this.buildChatContext(message)

      const response = await fetch('/chat', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({
          message: message,
          context: context
        })
      })

      if (response.ok) {
        const data = await response.json()
        this.updateChatMessage(loadingId, data.response)
      } else {
        this.updateChatMessage(loadingId, 'Sorry, I encountered an error. Please try again.')
      }
    } catch (error) {
      console.error('Chat error:', error)
      this.updateChatMessage(loadingId, 'Sorry, I encountered an error. Please try again.')
    }
  }

  // Add message to chat
  addChatMessage(sender, message, isLoading = false) {
    const messageId = `chat-message-${Date.now()}`
    const senderColor = sender === 'user' ? 'bg-blue-600 text-white' : 'bg-gray-100 text-gray-800'
    const senderLabel = sender === 'user' ? 'You' : 'AI'

    const messageHtml = `
      <div id="${messageId}" class="flex items-start space-x-2">
        <div class="flex-shrink-0 w-6 h-6 ${senderColor} rounded-full flex items-center justify-center text-xs font-medium">
          ${senderLabel === 'You' ? 'U' : 'AI'}
        </div>
        <div class="flex-1 text-sm text-gray-800">
          ${isLoading ? '<span class="animate-pulse">' + message + '</span>' : message}
        </div>
      </div>
    `

    if (this.hasChatMessagesTarget) {
      this.chatMessagesTarget.insertAdjacentHTML('beforeend', messageHtml)
      this.chatMessagesTarget.scrollTop = this.chatMessagesTarget.scrollHeight
    }

    return messageId
  }

  // Update existing chat message
  updateChatMessage(messageId, newMessage) {
    const messageElement = document.getElementById(messageId)
    if (messageElement) {
      const messageContent = messageElement.querySelector('.flex-1')
      if (messageContent) {
        messageContent.innerHTML = `<span class="text-sm text-gray-800">${newMessage}</span>`
      }
    }
  }

  // Build context for AI chat
  buildChatContext(message) {
    let context = `Course: ${document.title}\n`

    if (this.currentStepId) {
      const stepElement = this.stepButtonTargets.find(btn =>
        parseInt(btn.dataset.stepId) === this.currentStepId
      )

      if (stepElement) {
        const stepTitle = stepElement.querySelector('div > div').textContent.trim()
        context += `Current Step: ${stepTitle}\n`
      }

      // Add step content if available
      if (this.hasStepBodyTarget && this.stepBodyTarget.textContent) {
        const stepContent = this.stepBodyTarget.textContent.substring(0, 500) + '...'
        context += `Step Content: ${stepContent}\n`
      }
    }

    return context
  }

  // ==============================
  // QUIZ METHODS
  // ==============================

  loadQuizContent(quizId, stepId, moduleId, element) {
    console.log("Loading quiz content for quiz:", quizId)

    // Update active states first
    this.updateActiveStep(stepId, moduleId)

    // Show loading state in main content
    this.showQuizLoading(element)

    // Fetch quiz data
    fetch(`/quizzes/${quizId}.json`, {
      method: 'GET',
      headers: {
        'Accept': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').getAttribute('content')
      }
    })
    .then(response => {
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      return response.json()
    })
    .then(data => {
      console.log("Quiz data loaded:", data)
      this.renderQuizInterface(data, stepId, moduleId, element)
    })
    .catch(error => {
      console.error('Error loading quiz:', error)
      this.showNotification('Failed to load quiz. Please try again.', 'error')
      // Fallback to showing step content
      this.showStepContent(element, stepId, moduleId)
    })
  }

  showQuizLoading(element) {
    // Show step content and hide welcome first
    if (this.hasWelcomeStateTarget && this.hasStepContentTarget) {
      this.welcomeStateTarget.classList.add("hidden")
      this.stepContentTarget.classList.remove("hidden")
    }

    // Set loading content in stepBodyTarget (same target where quiz content will be rendered)
    if (this.hasStepBodyTarget) {
      this.stepBodyTarget.innerHTML = `
        <div class="flex items-center justify-center py-16">
          <div class="text-center">
            <div class="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600 mx-auto mb-4"></div>
            <p class="text-gray-600">Loading quiz...</p>
          </div>
        </div>
      `
    }
  }

  renderQuizInterface(quizData, stepId, moduleId, element) {
    console.log("Rendering quiz interface:", quizData)

    const quiz = quizData.quiz
    const currentAttempt = quizData.current_attempt
    const questions = quizData.questions || []

    // Update breadcrumbs
    if (this.hasBreadcrumbsTarget) {
      // Get step and module titles, handling null element case
      let stepTitle = quiz.title || 'Quiz'
      let moduleTitle = 'Module'

      if (element && element.dataset) {
        stepTitle = element.dataset.stepTitle || stepTitle
        moduleTitle = element.dataset.moduleTitle || moduleTitle
      }

      this.breadcrumbsTarget.innerHTML = `
        <span class="text-blue-600 cursor-pointer" data-action="click->course-docs#showWelcome">${quiz.course_title}</span>
        <span>›</span>
        <span class="text-blue-600 cursor-pointer">${moduleTitle}</span>
        <span>›</span>
        <span>${stepTitle}</span>
      `
    }

    // Update step title and meta
    if (this.hasStepTitleTarget) {
      this.stepTitleTarget.textContent = quiz.title || stepTitle
    }

    if (this.hasStepMetaTarget) {
      this.stepMetaTarget.innerHTML = `
        <span class="bg-purple-100 text-purple-800 px-2 py-1 rounded text-sm font-medium">📝 Quiz</span>
        <span class="text-gray-600">${quiz.total_points} points</span>
        ${quiz.time_limit_minutes ? `<span class="text-gray-600">⏱️ ${quiz.time_limit_minutes} minutes</span>` : ''}
        <span class="text-gray-600">${questions.length} questions</span>
      `
    }

    // Render quiz body content
    if (this.hasStepBodyTarget) {
      if (currentAttempt) {
        // User has an active attempt - show quiz taking interface
        this.renderQuizTakingInterface(quiz, currentAttempt, questions, quizData.responses || {})
      } else {
        // Show quiz introduction
        this.renderQuizIntroduction(quiz, quizData.best_attempt, quizData.user_attempts || [])
      }
    }

    // Update navigation
    this.updateStepNavigation(stepId)
  }

  renderQuizIntroduction(quiz, bestAttempt, userAttempts) {
    this.stepBodyTarget.innerHTML = `
      <div class="max-w-2xl">
        <div class="text-center mb-8">
          <div class="text-6xl mb-4">📝</div>
          <h2 class="text-2xl font-bold text-gray-900 mb-2">Ready to Start the Quiz?</h2>
          <p class="text-gray-600">
            This quiz will test your understanding of the concepts covered in this module.
            Take your time and read each question carefully.
          </p>
        </div>

        <!-- Quiz Information -->
        <div class="bg-gray-50 rounded-lg p-6 mb-6">
          <h3 class="font-semibold text-gray-900 mb-4">Quiz Details</h3>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-4 text-sm">
            <div class="flex items-center">
              <span class="text-blue-600 mr-2">📊</span>
              <span><strong>${quiz.question_count}</strong> questions</span>
            </div>
            <div class="flex items-center">
              <span class="text-green-600 mr-2">🎯</span>
              <span><strong>${quiz.total_points}</strong> total points</span>
            </div>
            <div class="flex items-center">
              <span class="text-orange-600 mr-2">⏱️</span>
              <span>
                ${quiz.time_limit_minutes ? `<strong>${quiz.time_limit_minutes}</strong> minute time limit` : 'No time limit'}
              </span>
            </div>
          </div>
        </div>

        ${bestAttempt ? `
        <!-- Best Score -->
        <div class="bg-green-50 border border-green-200 rounded-lg p-4 mb-6">
          <div class="flex items-center">
            <span class="text-green-600 text-2xl mr-3">🏆</span>
            <div>
              <h4 class="font-semibold text-green-900">Your Best Score</h4>
              <p class="text-green-700">
                <strong>${bestAttempt.percentage_score}%</strong>
                (${bestAttempt.score}/${bestAttempt.total_points} points)
              </p>
            </div>
          </div>
        </div>
        ` : ''}

        <!-- Start Quiz Button -->
        <div class="text-center mb-6">
          <button class="inline-flex items-center px-8 py-3 bg-blue-600 text-white font-semibold rounded-lg hover:bg-blue-700 transition-colors"
                  data-action="click->course-docs#startQuizAttempt"
                  data-quiz-id="${quiz.id}">
            <span class="mr-2">🚀</span>
            Start Quiz
          </button>
        </div>

        <!-- Instructions -->
        <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
          <h4 class="font-semibold text-blue-900 mb-2">Instructions</h4>
          <ul class="text-sm text-blue-800 space-y-1">
            <li>• Answer all questions to the best of your ability</li>
            <li>• Your progress is saved automatically</li>
            <li>• Once submitted, you cannot change your answers</li>
            ${quiz.time_limit_minutes ? `<li>• Complete the quiz within ${quiz.time_limit_minutes} minutes</li>` : ''}
            <li>• A passing score is 70% or higher</li>
          </ul>
        </div>
      </div>
    `
  }

    renderQuizTakingInterface(quiz, attempt, questions, responses) {
    // Initialize current question index
    this.currentQuestionIndex = 0
    this.quizQuestions = questions
    this.quizResponses = responses

    this.stepBodyTarget.innerHTML = `
      <div class="max-w-4xl">
        <!-- Quiz Progress -->
        <div class="bg-gray-50 rounded-lg p-4 mb-6">
          <div class="flex items-center justify-between mb-2">
            <span class="text-sm font-medium text-gray-700">Progress</span>
            <span class="text-sm text-gray-500" id="quiz-progress-text">
              Question <span id="current-question-num">1</span> of ${questions.length}
            </span>
          </div>
          <div class="w-full bg-gray-200 rounded-full h-2">
            <div class="bg-blue-600 h-2 rounded-full transition-all duration-300"
                 id="quiz-progress-bar"
                 style="width: ${(1 / questions.length * 100).toFixed(1)}%">
            </div>
          </div>
          ${quiz.time_limit_minutes && attempt.remaining_time_minutes > 0 ? `
          <div class="mt-3 flex items-center justify-between text-sm">
            <span class="text-yellow-800">Time Remaining:</span>
            <span class="font-bold text-yellow-900" id="quiz-timer">
              ${attempt.remaining_time_minutes} minutes
            </span>
          </div>
          ` : ''}

          <!-- Answered Status -->
          <div class="mt-3 text-sm text-gray-600">
            <span id="answered-count">${Object.keys(responses).length}</span> of ${questions.length} questions answered
          </div>
        </div>

        <!-- Single Question Display -->
        <form id="quiz-form" data-quiz-id="${quiz.id}" data-attempt-id="${attempt.id}">
          <div id="current-question-container">
            <!-- Question will be rendered here -->
          </div>

          <!-- Navigation Section -->
          <div class="border-t pt-6 mt-8">
            <div class="flex items-center justify-between">
              <!-- Previous Button -->
              <button type="button"
                      id="prev-question-btn"
                      class="px-4 py-2 border border-gray-300 rounded-lg text-gray-700 hover:bg-gray-50 transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                      data-action="click->course-docs#previousQuestion"
                      disabled>
                ← Previous
              </button>

              <!-- Question Navigation Dots -->
              <div class="flex space-x-2" id="question-dots">
                ${questions.map((_, index) => `
                  <button type="button"
                          class="w-3 h-3 rounded-full transition-colors ${index === 0 ? 'bg-blue-600' : 'bg-gray-300'}"
                          data-action="click->course-docs#goToQuestion"
                          data-question-index="${index}"
                          id="dot-${index}">
                  </button>
                `).join('')}
              </div>

              <!-- Next/Submit Button -->
              <button type="button"
                      id="next-question-btn"
                      class="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
                      data-action="click->course-docs#nextQuestion">
                Next →
              </button>
            </div>
          </div>
        </form>
      </div>
    `

    // Setup quiz interactions and render first question
    this.setupQuizInteractions(quiz, attempt, questions.length)
    this.renderCurrentQuestion()
  }

  renderQuestions(questions, responses) {
    return questions.map((question, index) => {
      const response = responses[question.id]

      return `
        <div class="question-block" data-question-id="${question.id}">
          <!-- Question Header -->
          <div class="flex items-start justify-between mb-4">
            <div class="flex-1">
              <div class="flex items-center space-x-2 mb-2">
                <span class="bg-gray-100 text-gray-800 text-sm font-medium px-2.5 py-0.5 rounded">
                  Q${index + 1}
                </span>
                <span class="text-sm text-gray-500">${question.points} points</span>
                <span class="text-xs bg-blue-100 text-blue-800 px-2 py-1 rounded">
                  ${question.question_type.replace('_', ' ')}
                </span>
              </div>
              <h3 class="text-lg font-medium text-gray-900 leading-relaxed mb-4">
                ${question.question_text}
              </h3>
            </div>
          </div>

          <!-- Answer Options -->
          <div class="ml-6">
            ${this.renderQuestionOptions(question, response)}
          </div>

          <!-- Status Indicator -->
          <div class="ml-6 mt-3">
            <span class="question-status inline-flex items-center text-sm ${response ? 'text-green-600' : 'text-gray-400'}">
              <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                ${response ?
                  '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>' :
                  '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>'
                }
              </svg>
              ${response ? 'Answered' : 'Not answered'}
            </span>
          </div>
        </div>
      `
    }).join('')
  }

    renderQuestionOptions(question, response) {
    switch (question.question_type) {
      case 'multiple_choice':
      case 'true_false':
        return question.options.map((option, index) => `
          <label class="flex items-center p-4 border border-gray-200 rounded-lg hover:bg-blue-50 cursor-pointer transition-colors group">
            <input type="radio"
                   name="questions[${question.id}][selected_option_id]"
                   value="${option.id}"
                   ${response && response.selected_option_id == option.id ? 'checked' : ''}
                   class="sr-only peer"
                   data-action="change->course-docs#handleSingleQuestionChange">
            <div class="w-5 h-5 border-2 border-gray-300 rounded-full mr-4 peer-checked:border-blue-600 peer-checked:bg-blue-600 flex items-center justify-center group-hover:border-blue-400 transition-colors">
              <div class="w-2.5 h-2.5 bg-white rounded-full opacity-0 peer-checked:opacity-100"></div>
            </div>
            <span class="text-gray-900 text-lg group-hover:text-blue-700 transition-colors">${option.option_text}</span>
          </label>
        `).join('')

      case 'short_answer':
        return `
          <div class="space-y-2">
            <label class="block text-sm font-medium text-gray-700">Your answer:</label>
            <textarea name="questions[${question.id}][answer_text]"
                      placeholder="Enter your answer here..."
                      rows="5"
                      data-action="input->course-docs#handleSingleQuestionChange"
                      class="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 resize-vertical text-lg">${response ? response.answer_text || '' : ''}</textarea>
            <p class="text-sm text-gray-500">Provide a detailed answer to the question above.</p>
          </div>
        `

      default:
        return '<p class="text-red-500">Unknown question type</p>'
    }
  }

  handleSingleQuestionChange(event) {
    // Update the question status immediately
    const questionBlock = event.target.closest('.question-block')
    if (questionBlock) {
      this.updateSingleQuestionStatus(questionBlock)
    }

    // Update navigation dots and answered count
    this.updateQuizNavigation()

    // Auto-save after a delay
    clearTimeout(this.autoSaveTimeout)
    this.autoSaveTimeout = setTimeout(() => {
      this.saveCurrentAnswer()
    }, 1500)
  }

  updateSingleQuestionStatus(questionBlock) {
    const questionId = questionBlock.dataset.questionId
    const statusElement = questionBlock.querySelector('.question-status')

    // Check if question is answered
    const radioChecked = questionBlock.querySelector('input[type="radio"]:checked')
    const textareaFilled = questionBlock.querySelector('textarea')?.value?.trim()

    const isAnswered = radioChecked || textareaFilled

    if (statusElement) {
      statusElement.innerHTML = `
        <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          ${isAnswered ?
            '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>' :
            '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>'
          }
        </svg>
        ${isAnswered ? 'Answered' : 'Not answered yet'}
      `
      statusElement.className = `question-status inline-flex items-center text-sm ${isAnswered ? 'text-green-600' : 'text-orange-500'}`
    }
  }

  setupQuizInteractions(quiz, attempt, totalQuestions) {
    this.currentQuiz = quiz
    this.currentAttempt = attempt
    this.totalQuestions = totalQuestions

    // Setup timer if needed
    if (quiz.time_limit_minutes && attempt.remaining_time_minutes > 0) {
      this.startQuizTimer(attempt.remaining_time_minutes)
    }

    // Setup auto-save
    this.setupAutoSave()
  }

  renderCurrentQuestion() {
    if (!this.quizQuestions || this.currentQuestionIndex >= this.quizQuestions.length) {
      console.error("Invalid question index or no questions available")
      return
    }

    const question = this.quizQuestions[this.currentQuestionIndex]
    const response = this.quizResponses[question.id]

    const questionContainer = document.getElementById('current-question-container')
    if (!questionContainer) return

    questionContainer.innerHTML = `
      <div class="question-block mb-8" data-question-id="${question.id}">
        <!-- Question Header -->
        <div class="mb-6">
          <div class="flex items-center space-x-3 mb-4">
            <span class="bg-blue-100 text-blue-800 text-lg font-bold px-4 py-2 rounded-full">
              Q${this.currentQuestionIndex + 1}
            </span>
            <span class="text-sm text-gray-500 bg-gray-100 px-3 py-1 rounded-full">
              ${question.points} ${question.points === 1 ? 'point' : 'points'}
            </span>
            <span class="text-xs bg-purple-100 text-purple-800 px-3 py-1 rounded-full">
              ${question.question_type.replace('_', ' ')}
            </span>
          </div>

          <h3 class="text-xl font-medium text-gray-900 leading-relaxed mb-6">
            ${question.question_text}
          </h3>
        </div>

        <!-- Answer Options -->
        <div class="space-y-3">
          ${this.renderQuestionOptions(question, response)}
        </div>

        <!-- Answer Status -->
        <div class="mt-4 pt-4 border-t border-gray-100">
          <div class="flex items-center justify-between">
            <span class="question-status inline-flex items-center text-sm ${response ? 'text-green-600' : 'text-orange-500'}">
              <svg class="w-4 h-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                ${response ?
                  '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>' :
                  '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>'
                }
              </svg>
              ${response ? 'Answered' : 'Not answered yet'}
            </span>

            <button type="button"
                    class="text-sm text-blue-600 hover:text-blue-800 transition-colors"
                    data-action="click->course-docs#saveCurrentAnswer">
              💾 Save Answer
            </button>
          </div>
        </div>
      </div>
    `

    // Update navigation state
    this.updateQuizNavigation()
  }

  nextQuestion() {
    // Auto-save current answer before moving
    this.saveCurrentAnswer()

    if (this.currentQuestionIndex < this.quizQuestions.length - 1) {
      this.currentQuestionIndex++
      this.renderCurrentQuestion()
    } else {
      // On last question, show submit dialog
      this.showSubmitDialog()
    }
  }

  previousQuestion() {
    if (this.currentQuestionIndex > 0) {
      // Auto-save current answer before moving
      this.saveCurrentAnswer()

      this.currentQuestionIndex--
      this.renderCurrentQuestion()
    }
  }

  goToQuestion(event) {
    const questionIndex = parseInt(event.target.dataset.questionIndex)
    if (questionIndex >= 0 && questionIndex < this.quizQuestions.length) {
      // Auto-save current answer before moving
      this.saveCurrentAnswer()

      this.currentQuestionIndex = questionIndex
      this.renderCurrentQuestion()
    }
  }

  saveCurrentAnswer() {
    const form = document.getElementById('quiz-form')
    if (!form) return

    const question = this.quizQuestions[this.currentQuestionIndex]
    if (!question) return

    let hasAnswer = false
    let answerValue = null

    // Get the current answer based on question type
    switch (question.question_type) {
      case 'multiple_choice':
      case 'true_false':
        const selectedOption = form.querySelector(`input[name="questions[${question.id}][selected_option_id]"]:checked`)
        if (selectedOption) {
          hasAnswer = true
          answerValue = selectedOption.value
        }
        break

      case 'short_answer':
        const textAnswer = form.querySelector(`textarea[name="questions[${question.id}][answer_text]"]`)
        if (textAnswer && textAnswer.value.trim()) {
          hasAnswer = true
          answerValue = textAnswer.value.trim()
        }
        break
    }

    // Update local responses object
    if (hasAnswer) {
      this.quizResponses[question.id] = {
        selected_option_id: question.question_type === 'short_answer' ? null : answerValue,
        answer_text: question.question_type === 'short_answer' ? answerValue : null
      }
    } else {
      delete this.quizResponses[question.id]
    }

    // Update answered count
    this.updateAnsweredCount()

    // Auto-save to server
    this.saveQuizProgress()
  }

  updateQuizNavigation() {
    const prevBtn = document.getElementById('prev-question-btn')
    const nextBtn = document.getElementById('next-question-btn')
    const currentQuestionNum = document.getElementById('current-question-num')
    const progressBar = document.getElementById('quiz-progress-bar')

    // Update current question number
    if (currentQuestionNum) {
      currentQuestionNum.textContent = this.currentQuestionIndex + 1
    }

    // Update progress bar (based on current question position)
    if (progressBar) {
      const progressPercentage = ((this.currentQuestionIndex + 1) / this.quizQuestions.length) * 100
      progressBar.style.width = `${progressPercentage}%`
    }

    // Update previous button
    if (prevBtn) {
      prevBtn.disabled = this.currentQuestionIndex === 0
    }

    // Update next/submit button
    if (nextBtn) {
      const isLastQuestion = this.currentQuestionIndex === this.quizQuestions.length - 1
      if (isLastQuestion) {
        nextBtn.textContent = '✅ Submit Quiz'
        nextBtn.className = 'px-4 py-2 bg-green-600 text-white rounded-lg hover:bg-green-700 transition-colors'
      } else {
        nextBtn.textContent = 'Next →'
        nextBtn.className = 'px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors'
      }
    }

    // Update navigation dots
    const dots = document.querySelectorAll('#question-dots button')
    dots.forEach((dot, index) => {
      const hasAnswer = this.quizResponses[this.quizQuestions[index].id]

      if (index === this.currentQuestionIndex) {
        // Current question
        dot.className = 'w-3 h-3 rounded-full bg-blue-600 transition-colors'
      } else if (hasAnswer) {
        // Answered question
        dot.className = 'w-3 h-3 rounded-full bg-green-500 transition-colors'
      } else {
        // Unanswered question
        dot.className = 'w-3 h-3 rounded-full bg-gray-300 transition-colors'
      }
    })
  }

  updateAnsweredCount() {
    const answeredCount = Object.keys(this.quizResponses).length
    const answeredCountElement = document.getElementById('answered-count')

    if (answeredCountElement) {
      answeredCountElement.textContent = answeredCount
    }
  }

  showSubmitDialog() {
    const answeredCount = Object.keys(this.quizResponses).length
    const totalQuestions = this.quizQuestions.length
    const unansweredCount = totalQuestions - answeredCount

    let message = `Are you sure you want to submit your quiz?\n\n`
    message += `• Answered: ${answeredCount}/${totalQuestions} questions\n`

    if (unansweredCount > 0) {
      message += `• Unanswered: ${unansweredCount} questions will be marked as incorrect\n`
    }

    message += `\nYou won't be able to change your answers after submission.`

    if (confirm(message)) {
      this.submitQuizAttempt({ target: document.getElementById('next-question-btn') })
    }
  }

  startQuizAttempt(event) {
    const quizId = event.target.dataset.quizId
    console.log("Starting quiz attempt for quiz:", quizId)

    // Show loading
    event.target.textContent = 'Starting...'
    event.target.disabled = true

    // Start quiz attempt
    fetch(`/quizzes/${quizId}/start.json`, {
      method: 'POST',
      headers: {
        'Accept': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').getAttribute('content')
      }
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        // Reload quiz content to show the taking interface
        this.loadQuizContent(quizId, this.currentStepId, this.currentModuleId, this.currentStepElement)
      } else {
        this.showNotification(data.message || 'Failed to start quiz', 'error')
      }
    })
    .catch(error => {
      console.error('Error starting quiz:', error)
      this.showNotification('Failed to start quiz. Please try again.', 'error')
    })
    .finally(() => {
      event.target.textContent = 'Start Quiz'
      event.target.disabled = false
    })
  }

  handleQuestionChange(event) {
    // Update progress indicators
    this.updateQuizProgress()

    // Update question status
    const questionBlock = event.target.closest('.question-block')
    if (questionBlock) {
      this.updateQuestionStatus(questionBlock)
    }

    // Auto-save after a delay
    clearTimeout(this.autoSaveTimeout)
    this.autoSaveTimeout = setTimeout(() => {
      this.saveQuizProgress()
    }, 2000)
  }

  updateQuizProgress() {
    const form = document.getElementById('quiz-form')
    if (!form) return

    const answeredQuestions = this.getAnsweredQuestionCount(form)
    const progressPercentage = (answeredQuestions / this.totalQuestions) * 100

    // Update progress bar
    const progressBar = document.getElementById('quiz-progress-bar')
    if (progressBar) {
      progressBar.style.width = `${progressPercentage}%`
    }

    // Update progress text
    const progressText = document.getElementById('quiz-progress-text')
    if (progressText) {
      progressText.textContent = `${answeredQuestions} of ${this.totalQuestions} questions answered`
    }

    // Update answered count
    const answeredCount = document.getElementById('answered-count')
    if (answeredCount) {
      answeredCount.textContent = answeredQuestions
    }

    // Update submit button
    const submitBtn = document.getElementById('quiz-submit-btn')
    if (submitBtn) {
      const allAnswered = answeredQuestions === this.totalQuestions
      submitBtn.textContent = allAnswered ? 'Submit Quiz' : `Submit Quiz (${this.totalQuestions - answeredQuestions} unanswered)`
      submitBtn.classList.toggle('bg-orange-600', !allAnswered)
      submitBtn.classList.toggle('hover:bg-orange-700', !allAnswered)
      submitBtn.classList.toggle('bg-blue-600', allAnswered)
      submitBtn.classList.toggle('hover:bg-blue-700', allAnswered)
    }
  }

  updateQuestionStatus(questionBlock) {
    const questionId = questionBlock.dataset.questionId
    const statusElement = questionBlock.querySelector('.question-status')

    // Check if question is answered
    const radioChecked = questionBlock.querySelector('input[type="radio"]:checked')
    const textareaFilled = questionBlock.querySelector('textarea')?.value?.trim()

    const isAnswered = radioChecked || textareaFilled

    if (statusElement) {
      statusElement.innerHTML = `
        <svg class="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          ${isAnswered ?
            '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>' :
            '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"></path>'
          }
        </svg>
        ${isAnswered ? 'Answered' : 'Not answered'}
      `
      statusElement.className = `question-status inline-flex items-center text-sm ${isAnswered ? 'text-green-600' : 'text-gray-400'}`
    }
  }

  getAnsweredQuestionCount(form) {
    let count = 0

    // Count radio button groups
    const radioGroups = new Set()
    form.querySelectorAll('input[type="radio"]:checked').forEach(radio => {
      radioGroups.add(radio.name)
    })
    count += radioGroups.size

    // Count filled textareas
    form.querySelectorAll('textarea').forEach(textarea => {
      if (textarea.value.trim() !== '') {
        count++
      }
    })

    return count
  }

  saveQuizProgress() {
    const form = document.getElementById('quiz-form')
    if (!form || !this.currentAttempt) return

    console.log("Auto-saving quiz progress...")

    const formData = new FormData(form)

    fetch(`/quizzes/${this.currentQuiz.id}/save_progress.json`, {
      method: 'PATCH',
      body: formData,
      headers: {
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').getAttribute('content')
      }
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        console.log("Progress saved successfully")
        this.showNotification('Progress saved automatically', 'success', 2000)
      }
    })
    .catch(error => {
      console.error('Error saving progress:', error)
    })
  }

  submitQuizAttempt(event) {
    event.preventDefault()

    const form = document.getElementById('quiz-form')
    if (!form || !this.currentAttempt) return

    if (!confirm('Are you sure you want to submit your quiz? You won\'t be able to change your answers after submission.')) {
      return
    }

    console.log("Submitting quiz...")

    // Show loading state
    const submitBtn = event.target
    const originalText = submitBtn.textContent
    submitBtn.textContent = 'Submitting...'
    submitBtn.disabled = true

    const formData = new FormData(form)

    fetch(`/quizzes/${this.currentQuiz.id}/submit.json`, {
      method: 'PATCH',
      body: formData,
      headers: {
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').getAttribute('content')
      }
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        this.showNotification('Quiz submitted successfully!', 'success')
        // Show results
        setTimeout(() => {
          this.loadQuizResults(this.currentQuiz.id)
        }, 1000)
      } else {
        this.showNotification(data.message || 'Failed to submit quiz', 'error')
      }
    })
    .catch(error => {
      console.error('Error submitting quiz:', error)
      this.showNotification('Failed to submit quiz. Please try again.', 'error')
    })
    .finally(() => {
      submitBtn.textContent = originalText
      submitBtn.disabled = false
    })
  }

  loadQuizResults(quizId) {
    fetch(`/quizzes/${quizId}/results.json`, {
      method: 'GET',
      headers: {
        'Accept': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').getAttribute('content')
      }
    })
    .then(response => response.json())
    .then(data => {
      this.renderQuizResults(data)
    })
    .catch(error => {
      console.error('Error loading quiz results:', error)
      this.showNotification('Failed to load results. Please refresh the page.', 'error')
    })
  }

  renderQuizResults(data) {
    const attempt = data.attempt
    const questionsWithResponses = data.questions_with_responses

    this.stepBodyTarget.innerHTML = `
      <div class="max-w-4xl">
        <!-- Results Summary -->
        <div class="text-center mb-8">
          <div class="mb-6">
            ${attempt.passed ? `
              <div class="text-6xl mb-4">🎉</div>
              <h2 class="text-3xl font-bold text-green-600 mb-2">Congratulations!</h2>
              <p class="text-lg text-gray-600">You passed the quiz!</p>
            ` : `
              <div class="text-6xl mb-4">📚</div>
              <h2 class="text-3xl font-bold text-orange-600 mb-2">Keep Learning!</h2>
              <p class="text-lg text-gray-600">You can retake this quiz to improve your score.</p>
            `}
          </div>

          <!-- Score Display -->
          <div class="bg-gray-50 rounded-lg p-6 mb-6">
            <div class="grid grid-cols-1 md:grid-cols-4 gap-6 text-center">
              <div>
                <div class="text-2xl font-bold text-blue-600">
                  ${attempt.percentage_score}%
                </div>
                <div class="text-sm text-gray-600">Final Score</div>
              </div>
              <div>
                <div class="text-2xl font-bold text-gray-900">
                  ${attempt.score}/${attempt.total_points}
                </div>
                <div class="text-sm text-gray-600">Points Earned</div>
              </div>
              <div>
                <div class="text-2xl font-bold text-green-600">
                  ${questionsWithResponses.filter(q => q.is_correct).length}/${questionsWithResponses.length}
                </div>
                <div class="text-sm text-gray-600">Correct Answers</div>
              </div>
              <div>
                <div class="text-2xl font-bold text-purple-600">
                  ${attempt.time_spent_minutes}m
                </div>
                <div class="text-sm text-gray-600">Time Spent</div>
              </div>
            </div>
          </div>

          <!-- Action Buttons -->
          <div class="flex gap-4 justify-center">
            <button class="px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
                    data-action="click->course-docs#showWelcome">
              📚 Continue Course
            </button>
            <button class="px-6 py-3 border border-gray-300 text-gray-700 rounded-lg hover:bg-gray-50 transition-colors"
                    data-action="click->course-docs#retakeQuiz"
                    data-quiz-id="${this.currentQuiz.id}">
              🔄 Retake Quiz
            </button>
          </div>
        </div>
      </div>
    `
  }

  retakeQuiz(event) {
    const quizId = event.target.dataset.quizId
    this.loadQuizContent(quizId, this.currentStepId, this.currentModuleId, this.currentStepElement)
  }

  setupAutoSave() {
    // Auto-save every 2 minutes
    this.autoSaveInterval = setInterval(() => {
      this.saveQuizProgress()
    }, 120000)
  }

  startQuizTimer(remainingMinutes) {
    let timeLeft = remainingMinutes

    this.timerInterval = setInterval(() => {
      if (timeLeft > 0) {
        const timerElement = document.getElementById('quiz-timer')
        if (timerElement) {
          timerElement.textContent = `${timeLeft} minutes`

          // Warning when under 5 minutes
          if (timeLeft <= 5) {
            timerElement.className = 'font-bold text-red-900'
            timerElement.closest('.bg-gray-50').classList.add('bg-red-50', 'border-red-200')
          }
        }
        timeLeft--
      } else {
        // Time's up!
        this.handleTimeUp()
      }
    }, 60000) // Update every minute
  }

  handleTimeUp() {
    clearInterval(this.timerInterval)
    this.showNotification('⏰ Time is up! Your quiz will be submitted automatically.', 'error', 5000)

    setTimeout(() => {
      const submitBtn = document.getElementById('quiz-submit-btn')
      if (submitBtn) {
        submitBtn.click()
      }
    }, 3000)
  }

  showNotification(message, type = 'info', duration = 4000) {
    // Create notification element
    const notification = document.createElement('div')
    notification.className = `fixed top-4 right-4 z-50 p-4 rounded-lg shadow-lg transition-all duration-300 transform translate-x-full max-w-sm`

    // Set styles based on type
    switch (type) {
      case 'success':
        notification.classList.add('bg-green-100', 'border', 'border-green-400', 'text-green-700')
        break
      case 'error':
        notification.classList.add('bg-red-100', 'border', 'border-red-400', 'text-red-700')
        break
      case 'warning':
        notification.classList.add('bg-yellow-100', 'border', 'border-yellow-400', 'text-yellow-700')
        break
      default:
        notification.classList.add('bg-blue-100', 'border', 'border-blue-400', 'text-blue-700')
    }

    notification.innerHTML = `
      <div class="flex items-start">
        <span class="flex-1 text-sm">${message}</span>
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

    // Auto-remove
    setTimeout(() => {
      notification.classList.add('translate-x-full')
      setTimeout(() => {
        if (notification.parentElement) {
          notification.remove()
        }
      }, 300)
    }, duration)
  }

  // Store current step info for quiz interactions
  updateActiveStep(stepId, moduleId) {
    this.currentStepId = stepId
    this.currentModuleId = moduleId

    // Find the current step element
    this.currentStepElement = this.stepButtonTargets.find(btn =>
      parseInt(btn.dataset.stepId) === stepId
    )

    // Remove all active states
    this.stepButtonTargets.forEach(btn => {
      btn.classList.remove("bg-blue-100", "text-blue-900", "border-blue-200")
      btn.classList.add("text-gray-700")
    })

    // Add active state to current step
    if (this.currentStepElement) {
      this.currentStepElement.classList.remove("text-gray-700")
      this.currentStepElement.classList.add("bg-blue-100", "text-blue-900", "border-blue-200")
    }
  }

  showWelcome() {
    console.log("Showing welcome state")

    // Hide step content and show welcome state
    if (this.hasWelcomeStateTarget && this.hasStepContentTarget) {
      this.stepContentTarget.classList.add("hidden")
      this.welcomeStateTarget.classList.remove("hidden")
    }

    // Clear active step states
    this.stepButtonTargets.forEach(btn => {
      btn.classList.remove("bg-blue-100", "text-blue-900", "border-blue-200")
      btn.classList.add("text-gray-700")
    })

    // Clear current step tracking
    this.currentStepId = null
    this.currentModuleId = null
    this.currentStepElement = null

    // Clear quiz state
    this.currentQuiz = null
    this.currentAttempt = null

    // Cleanup timers
    if (this.timerInterval) {
      clearInterval(this.timerInterval)
      this.timerInterval = null
    }
    if (this.autoSaveInterval) {
      clearInterval(this.autoSaveInterval)
      this.autoSaveInterval = null
    }
    if (this.autoSaveTimeout) {
      clearTimeout(this.autoSaveTimeout)
      this.autoSaveTimeout = null
    }
  }

  disconnect() {
    // Cleanup timers when controller is disconnected
    if (this.timerInterval) {
      clearInterval(this.timerInterval)
    }
    if (this.autoSaveInterval) {
      clearInterval(this.autoSaveInterval)
    }
    if (this.autoSaveTimeout) {
      clearTimeout(this.autoSaveTimeout)
    }
  }
}
