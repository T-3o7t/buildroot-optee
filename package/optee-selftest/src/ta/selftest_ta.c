// SPDX-License-Identifier: BSD-2-Clause
/* Custom OP-TEE self-test TA: exercises value passing, in-TEE SHA-256
 * (GlobalPlatform crypto API) and the secure-world TRNG. */
#include <tee_internal_api.h>
#include <tee_internal_api_extensions.h>

#include <selftest_ta.h>

TEE_Result TA_CreateEntryPoint(void) { return TEE_SUCCESS; }
void TA_DestroyEntryPoint(void) { }

TEE_Result TA_OpenSessionEntryPoint(uint32_t pt,
				    TEE_Param __unused params[4],
				    void __unused **sess)
{
	if (pt != TEE_PARAM_TYPES(TEE_PARAM_TYPE_NONE, TEE_PARAM_TYPE_NONE,
				  TEE_PARAM_TYPE_NONE, TEE_PARAM_TYPE_NONE))
		return TEE_ERROR_BAD_PARAMETERS;
	IMSG("selftest TA: session opened");
	return TEE_SUCCESS;
}

void TA_CloseSessionEntryPoint(void __unused *sess)
{
	IMSG("selftest TA: session closed");
}

static TEE_Result cmd_inc(uint32_t pt, TEE_Param p[4])
{
	if (pt != TEE_PARAM_TYPES(TEE_PARAM_TYPE_VALUE_INOUT,
				  TEE_PARAM_TYPE_NONE, TEE_PARAM_TYPE_NONE,
				  TEE_PARAM_TYPE_NONE))
		return TEE_ERROR_BAD_PARAMETERS;
	p[0].value.a += 1;
	return TEE_SUCCESS;
}

static TEE_Result cmd_sum(uint32_t pt, TEE_Param p[4])
{
	if (pt != TEE_PARAM_TYPES(TEE_PARAM_TYPE_VALUE_INPUT,
				  TEE_PARAM_TYPE_VALUE_OUTPUT,
				  TEE_PARAM_TYPE_NONE, TEE_PARAM_TYPE_NONE))
		return TEE_ERROR_BAD_PARAMETERS;
	p[1].value.a = p[0].value.a + p[0].value.b;
	p[1].value.b = 0;
	return TEE_SUCCESS;
}

/* SHA-256 computed entirely inside the secure world. */
static TEE_Result cmd_sha256(uint32_t pt, TEE_Param p[4])
{
	TEE_OperationHandle op = TEE_HANDLE_NULL;
	TEE_Result res;
	uint32_t dlen;

	if (pt != TEE_PARAM_TYPES(TEE_PARAM_TYPE_MEMREF_INPUT,
				  TEE_PARAM_TYPE_MEMREF_OUTPUT,
				  TEE_PARAM_TYPE_NONE, TEE_PARAM_TYPE_NONE))
		return TEE_ERROR_BAD_PARAMETERS;
	if (p[1].memref.size < 32) {
		p[1].memref.size = 32;
		return TEE_ERROR_SHORT_BUFFER;
	}

	res = TEE_AllocateOperation(&op, TEE_ALG_SHA256, TEE_MODE_DIGEST, 0);
	if (res != TEE_SUCCESS)
		return res;

	dlen = p[1].memref.size;
	res = TEE_DigestDoFinal(op, p[0].memref.buffer, p[0].memref.size,
				p[1].memref.buffer, &dlen);
	if (res == TEE_SUCCESS)
		p[1].memref.size = dlen;

	TEE_FreeOperation(op);
	return res;
}

/* Fill the output buffer with secure-world random bytes. */
static TEE_Result cmd_random(uint32_t pt, TEE_Param p[4])
{
	if (pt != TEE_PARAM_TYPES(TEE_PARAM_TYPE_MEMREF_OUTPUT,
				  TEE_PARAM_TYPE_NONE, TEE_PARAM_TYPE_NONE,
				  TEE_PARAM_TYPE_NONE))
		return TEE_ERROR_BAD_PARAMETERS;
	TEE_GenerateRandom(p[0].memref.buffer, p[0].memref.size);
	return TEE_SUCCESS;
}

TEE_Result TA_InvokeCommandEntryPoint(void __unused *sess, uint32_t cmd,
				      uint32_t pt, TEE_Param p[4])
{
	switch (cmd) {
	case TA_SELFTEST_CMD_INC:	return cmd_inc(pt, p);
	case TA_SELFTEST_CMD_SUM:	return cmd_sum(pt, p);
	case TA_SELFTEST_CMD_SHA256:	return cmd_sha256(pt, p);
	case TA_SELFTEST_CMD_RANDOM:	return cmd_random(pt, p);
	default:			return TEE_ERROR_NOT_SUPPORTED;
	}
}
