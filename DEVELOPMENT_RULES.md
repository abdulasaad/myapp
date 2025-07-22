# CRITICAL DEVELOPMENT RULES - AL-TIJWAL APP

## ⚠️ MANDATORY REQUIREMENTS - READ BEFORE ANY CHANGES

### **RULE #1: NO BREAKING CHANGES**
- **Any changes or fixes must NOT affect other functions**
- **Test existing functionality after every change**
- **If something worked before, it must continue working after**

### **RULE #2: UNIVERSAL IMPLEMENTATION**
- **Any new function must be implemented for ALL account types:**
  - Admin accounts
  - Manager accounts  
  - Agent accounts
  - Client accounts
- **No partial implementations that only work for some users**

### **RULE #3: NON-DESTRUCTIVE DEVELOPMENT**
- **Always preserve existing working functions**
- **Add new features WITHOUT modifying core existing logic**
- **Use defensive programming - check for existing functionality before changes**

### **RULE #4: COMPREHENSIVE TESTING**
- **Test ALL user roles after any change:**
  - Login/logout functionality
  - Navigation and screens
  - Data access and permissions
  - Campaign creation, editing, viewing
  - Live map and tracking features
  - Task assignments and management
- **Verify no regressions in existing features**

### **RULE #5: ROLLBACK CAPABILITY**
- **Keep backup of working code before major changes**
- **Document what was changed and why**
- **Be prepared to revert if issues arise**

## 🔧 IMPLEMENTATION CHECKLIST

Before making ANY changes, ask:
1. ✅ Will this change affect existing working functions?
2. ✅ Does this new feature work for Admin, Manager, Agent, AND Client?
3. ✅ Have I tested the change with all user types?
4. ✅ Can I rollback this change if needed?
5. ✅ Does this maintain backward compatibility?

## 🚨 USER'S EXPLICIT INSTRUCTION
**"any changes or fix do not effect on any other functions. any new function make sure to implemented to all application accounts related without effect on the working functions"**

## 📋 USER ROLE REQUIREMENTS
- **Admin**: Full system access, can see everything
- **Manager**: Campaign management, user oversight  
- **Agent**: Task completion, location tracking
- **Client**: Campaign monitoring, read-only dashboard

**FAILURE TO FOLLOW THESE RULES WILL RESULT IN SYSTEM INSTABILITY**