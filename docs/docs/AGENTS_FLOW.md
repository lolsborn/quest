## Roles

**Agent (AI)**    
- Creator
- Reviewer
- Manager

**Agents (Automation)**
- Tester
- Publisher

**Human**
- Requester
- Owner (This can often be the same as the Requester)
- Approver


## New Feature Process

### Steps

 1. Feature request is submitted
    - [Requester] Makes request via
        - Slack?
        - Jira?
 2. Quest Improvement Document QED-001*
    - [Manager] polls for incomign requests, creates prompts / instructions
        to kick off Creator.
    - [Creator] Creator makes specification from incoming request
    - [Reviewer] reviews specification, makes suggestions for improvements.  This 
        is _crucial_ as multi-pass is needed for good results
    - [Manager] integrates reviewers suggestions.  Submits QED-* to auditor.
        - Sends notification via Slack to Auditor
3. Checks CDS for completeness /  correctness 
    - [Owner]
        - audits if additions / revisions are needed.
        - If changes are required they are forwarded to the manager at step #2
4. Implement Feature
    - [Manger] sets up branch, creates prompts for creator,
    - [Creator]
        - Implements feature
        - Writes tests
        - Wites documentation
    - [Reviewer]
        - Reviews Feature
        - Reviews documentation
        - Runs automated tests suite
    - [Manager]
        - Runs Runs automated tests
        - Approves feature or kicks it back to Creator to iterate.
        - Notifies Owner and Approver
5. Code Review / Approval  
    - [Tester] 
        - Prevents code merge with failing tests
    - [Approver]
        - Reviews code.
        - If changes are needed kick back to #4 Manager
        - Otherwise push
    - [Publisher]
        - Automatically deploys code