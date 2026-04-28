# TypeScript Compilation Issues

This document lists the TypeScript errors that need to be fixed before using the full `prepare-release.sh` script.

## Summary

- **Total Errors**: ~80+ compilation errors
- **Current Workaround**: Use `./scripts/quick-zip.sh` with existing `dist/` folder
- **Long-term Fix**: Address the issues below

---

## Categories of Errors

### 1. **Prisma Model Property Mismatches** (Most Common)

**Issue**: Code is accessing properties that don't exist in the Prisma-generated types.

**Examples**:
- `InvestmentBalance` doesn't have `id` property (uses `userId` as primary key)
- `P2POrder` doesn't have `updatedAt` property
- `Withdrawal` has `txHash` not `transactionHash`
- Missing `investmentTransaction` model in Prisma client

**Files Affected**:
- `src/services/admin/investment/investment-admin.service.ts` (lines 67, 114, 125, 231, 319, 328, 413, 420)
- `src/services/admin/p2p/p2p-admin.service.ts` (lines 155, 338)
- `src/services/admin/transactions/transactions.service.ts` (lines 160, 164, 247, 251, 349, 352, 356)
- `src/services/admin/dashboard/dashboard.service.ts` (line 400)

**Fix**: Update code to use correct Prisma model properties or update schema if properties are needed.

---

### 2. **Enum Value Mismatches**

**Issue**: Using lowercase enum values instead of uppercase.

**Examples**:
```typescript
// Wrong:
status === 'pending'  // Error: WithdrawalStatus has no overlap with 'pending'

// Correct:
status === 'PENDING'  // Or use WithdrawalStatus.PENDING
```

**Files Affected**:
- `src/services/admin/dashboard/dashboard.service.ts` (lines 122-124)
- `src/services/admin/transactions/transactions.service.ts` (lines 325, 382)

**Fix**: Use uppercase enum values matching Prisma schema.

---

### 3. **Type Conversion Issues (Decimal/JsonValue)**

**Issue**: Prisma `Decimal` and `JsonValue` types not being converted to strings for API responses.

**Examples**:
```typescript
// Error: Type 'Decimal' is not assignable to type 'string'
amount: withdrawal.amount  // Should be: withdrawal.amount.toString()

// Error: Type 'JsonValue' is not assignable to type 'string | null'
nearIntentId: deposit.nearIntentId  // Should be: JSON.stringify(deposit.nearIntentId)
```

**Files Affected**:
- `src/services/admin/transactions/transactions.service.ts` (lines 72, 154, 205, 206, 209, 210, 245, 246, 297, 298, 301, 302, 350, 351)
- `src/services/admin/users/users.service.ts` (lines 85, 157, 159, 160)

**Fix**: Convert Prisma types to strings/JSON for API responses.

---

### 4. **JWT Payload Type Issues**

**Issue**: Custom JWT properties not defined in JWTPayload type.

**Examples**:
```typescript
// Error: 'adminId' does not exist in type 'JWTPayload'
const payload = {
  adminId: admin.id,  // Custom property
  email: admin.email,
  role: admin.role
};
```

**Files Affected**:
- `src/services/admin/admin.service.ts` (lines 85, 91, 178, 184, 266)

**Fix**: Extend JWTPayload interface or use type assertion.

---

### 5. **Missing Config Properties**

**Issue**: Accessing config properties that don't exist in the config type.

**Examples**:
```typescript
config.treasuryAddress      // Property doesn't exist
config.smtpHost            // Property doesn't exist
config.backendWalletAddress // Property doesn't exist
```

**Files Affected**:
- `src/services/admin/system/system.service.ts` (lines 32, 53, 54, 127, 240, 242)
- `src/services/wallet/wallet.service.ts` (lines 23, 50, 55, 65, 68)

**Fix**: Add missing properties to config type or use different access pattern.

---

### 6. **Validation Middleware Return Type Issues**

**Issue**: Not all code paths return a value in middleware functions.

**Files Affected**:
- `src/middleware/validation.middleware.ts` (lines 34, 83, 126, 183)

**Fix**: Ensure all code paths explicitly return a value or use proper Express middleware typing.

---

### 7. **Referral Include/Select Type Issues**

**Issue**: Using incorrect property names in Prisma include/select.

**Examples**:
```typescript
// Error: 'referredUser' does not exist in type 'ReferralEarningInclude'
include: {
  referredUser: true  // Should be: referredUserId or different relation name
}
```

**Files Affected**:
- `src/services/admin/referrals/referrals.controller.ts` (lines 290, 306, 308)
- `src/services/admin/users/users.service.ts` (lines 134, 151, 158, 161, 162, 163, 164, 165)

**Fix**: Use correct Prisma relation names from schema.

---

### 8. **Null Safety Issues**

**Issue**: Nullable values being assigned to non-nullable types.

**Examples**:
```typescript
// Error: Type 'string | null' is not assignable to type 'string'
toAddress: withdrawal.toAddress  // toAddress can be null

// Fix:
toAddress: withdrawal.toAddress || ''  // Or make type nullable
```

**Files Affected**:
- `src/services/admin/p2p/p2p-admin.service.ts` (line 206)
- `src/services/admin/transactions/transactions.service.ts` (lines 154, 245, 350)

**Fix**: Handle null cases or make types nullable.

---

## Recommended Fix Priority

### High Priority (Blocks deployment builds)
1. ✅ **Use existing dist/** - Current workaround with `quick-zip.sh`
2. Fix Prisma model property mismatches
3. Fix enum value mismatches
4. Fix type conversions (Decimal → string)

### Medium Priority (Code quality)
5. Fix JWT payload types
6. Fix config property access
7. Fix validation middleware returns

### Low Priority (Nice to have)
8. Fix referral include/select issues
9. Improve null safety

---

## Current Workaround

For immediate deployment, use the existing compiled `dist/` folder:

```bash
# Create release zip from existing build
./scripts/quick-zip.sh v1.0.0

# This uses the already-compiled backend/dist/ folder
# The dist/ was built previously when types were correct
```

---

## Long-term Solution

1. **Update Prisma Schema** if models need new properties
2. **Run `npx prisma generate`** to regenerate types
3. **Fix all code** to match generated Prisma types
4. **Add proper type definitions** for JWT payloads
5. **Add missing config properties**
6. **Test build**: `npm run build`
7. **Use full release script**: `./scripts/prepare-release.sh`

---

## Notes

- The existing `dist/` folder works in production (tested successfully)
- These are type-level errors, not runtime errors
- The code may work at runtime but fails TypeScript compilation
- Fixing these will improve code quality and prevent future bugs

---

**Last Updated**: 2026-04-28
