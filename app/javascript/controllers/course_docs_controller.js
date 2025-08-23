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

    console.log("Selecting step:", stepId, "from module:", moduleId)

    // Update active states
    this.updateActiveStep(stepId, moduleId)

    // Load step content from DOM data attributes
    this.loadStepContentFromElement(event.currentTarget)

    // Show step content and hide welcome
    if (this.hasWelcomeStateTarget && this.hasStepContentTarget) {
      this.welcomeStateTarget.classList.add("hidden")
      this.stepContentTarget.classList.remove("hidden")
    }

    // Update navigation buttons
    this.updateStepNavigation(stepId)
  }

  // Update active step styling
  updateActiveStep(stepId, moduleId) {
    // Remove all active states
    this.stepButtonTargets.forEach(btn => {
      btn.classList.remove("bg-blue-100", "text-blue-900", "border-blue-200")
      btn.classList.add("text-gray-700")
    })

    // Add active state to selected step
    const activeStepBtn = this.stepButtonTargets.find(btn =>
      parseInt(btn.dataset.stepId) === stepId
    )

    if (activeStepBtn) {
      activeStepBtn.classList.add("bg-blue-100", "text-blue-900", "border-blue-200")
      activeStepBtn.classList.remove("text-gray-700")
    }

    this.currentStepId = stepId
    this.currentModuleId = moduleId
  }

      // Load step content from DOM element data attributes
  loadStepContentFromElement(element) {
    console.log("Loading step content from DOM element")

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
}
