# Sample Documents for OnboardAI

This directory contains sample documents that can be used to test the document-based course generation functionality. Each document represents common organizational materials that would be used for employee onboarding and training.

## Available Documents

### 1. Developer Onboarding Guide (`developer_onboarding_guide.md`)
**Content**: Complete guide for new software developers
**Topics Covered**:
- Environment setup and prerequisites
- Git workflow and branch naming conventions
- Code review process and best practices
- Testing procedures and quality standards
- Development tools and resources
- Common troubleshooting scenarios

**Use Cases**: Generate courses for developer onboarding, coding standards training, or development process certification

---

### 2. Security Policy Guide (`security_policy_guide.md`)
**Content**: Comprehensive security policies and procedures
**Topics Covered**:
- Access control and authentication requirements
- Data classification and protection protocols
- Network security and VPN usage
- Device and workstation security standards
- Incident response procedures
- Software development security practices

**Use Cases**: Create security awareness training, compliance courses, or incident response training modules

---

### 3. HR Onboarding Checklist (`hr_onboarding_checklist.md`)
**Content**: Step-by-step new employee onboarding process
**Topics Covered**:
- Pre-arrival preparation checklist
- First day orientation schedule
- Benefits enrollment and explanation
- Training requirements and timelines
- Performance review processes
- Company contacts and resources

**Use Cases**: Generate HR training courses, manager onboarding programs, or new employee orientation materials

---

### 4. Customer Service Standards (`customer_service_standards.md`)
**Content**: Customer service excellence guidelines and procedures
**Topics Covered**:
- Response time standards and SLAs
- Communication best practices
- Customer interaction processes
- Handling difficult situations and escalations
- Quality assurance and performance metrics
- Common scenarios and standard responses

**Use Cases**: Create customer service training programs, quality assurance courses, or communication skills development

---

### 5. Sales Process Guide (`sales_process_guide.md`)
**Content**: Complete sales methodology and process documentation
**Topics Covered**:
- Lead qualification frameworks (BANT)
- Sales process stages and activities
- CRM management and pipeline hygiene
- Performance metrics and compensation
- Training and development programs
- Tools and resources for sales success

**Use Cases**: Generate sales training courses, onboarding programs for new sales reps, or sales management certification

---

### 6. Remote Work Policy (`remote_work_policy.md`)
**Content**: Comprehensive remote work guidelines and expectations
**Topics Covered**:
- Eligibility criteria and approval processes
- Home office setup requirements
- Communication and collaboration standards
- Performance management for remote workers
- Work-life balance and wellness guidelines
- Security and compliance requirements

**Use Cases**: Create remote work training, manager certification for remote teams, or policy compliance courses

---

### 7. Product Management Guide (`product_management_guide.md`)
**Content**: Product management methodology and best practices
**Topics Covered**:
- Product development lifecycle
- Feature prioritization frameworks
- Stakeholder management strategies
- Data-driven decision making
- Product launch strategies
- Roadmap planning and communication

**Use Cases**: Generate product management training, new PM onboarding courses, or advanced strategy workshops

## How to Use These Documents

### Testing Document-Based Course Generation

1. **Upload Documents**: Use the admin interface to upload one or more sample documents
2. **Create Conversation**: Start a new conversation in the course generator
3. **Reference Documents**: Use @filename syntax to reference uploaded documents
   ```
   Example: "Create a security training course using @security_policy_guide.md"
   ```
4. **Generate Course**: Follow the normal course generation process
5. **Verify Content**: Confirm that generated content is based on document information

### Example Conversation Prompts

**Single Document**:
```
"Generate a developer onboarding course using @developer_onboarding_guide.md"
```

**Multiple Documents**:
```
"Create a comprehensive new employee training program using @hr_onboarding_checklist.md and @security_policy_guide.md"
```

**Specific Focus**:
```
"Build a customer service excellence course focusing on communication standards from @customer_service_standards.md"
```

### Document Features for Testing

Each sample document includes:
- **Structured Content**: Headers, lists, and organized sections
- **Practical Examples**: Code snippets, templates, and real-world scenarios
- **Detailed Procedures**: Step-by-step processes and checklists
- **Policy Information**: Rules, standards, and compliance requirements
- **Best Practices**: Proven methods and recommendations
- **Resource Lists**: Tools, contacts, and reference materials

### Expected Course Generation Outcomes

When using these documents, the generated courses should:
- Extract specific procedures and requirements from the documents
- Create relevant learning objectives based on document content
- Generate quizzes that test knowledge of documented information
- Include practical exercises derived from document examples
- Maintain accuracy to the source material without external knowledge

## Document Customization

These sample documents can be modified to better match your testing needs:
- Update company names and contact information
- Adjust policies to match your organization's requirements
- Add or remove sections based on specific use cases
- Modify examples to reflect your industry or business model

## Quality Assurance

When testing with these documents, verify that:
- Generated content references specific information from the documents
- Quizzes test knowledge of documented procedures and policies
- Examples and scenarios come from the source material
- No external knowledge is added beyond what's in the documents
- Content maintains the tone and structure appropriate for training materials

---

*These sample documents are designed to comprehensively test the document-based course generation feature while representing realistic organizational materials that would commonly be used for employee training and onboarding.*
