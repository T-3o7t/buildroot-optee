// SPDX-License-Identifier: BSD-2-Clause
/* Host client for the custom OP-TEE self-test TA.
 * Exercises value passing, in-TEE SHA-256 and the secure-world TRNG,
 * verifying each result and reporting PASS/FAIL. */
#include <stdio.h>
#include <string.h>
#include <stdint.h>

#include <tee_client_api.h>
#include <selftest_ta.h>

static int failures;

static void check(const char *name, int ok)
{
	printf("[%s] %s\n", ok ? "PASS" : "FAIL", name);
	if (!ok)
		failures++;
}

/* SHA-256("abc") per FIPS 180-4. */
static const uint8_t sha256_abc[32] = {
	0xba,0x78,0x16,0xbf,0x8f,0x01,0xcf,0xea,0x41,0x41,0x40,0xde,0x5d,0xae,0x22,0x23,
	0xb0,0x03,0x61,0xa3,0x96,0x17,0x7a,0x9c,0xb4,0x10,0xff,0x61,0xf2,0x00,0x15,0xad
};

int main(void)
{
	TEEC_Context ctx;
	TEEC_Session sess;
	TEEC_Operation op;
	TEEC_UUID uuid = TA_SELFTEST_UUID;
	uint32_t origin;
	TEEC_Result res;

	res = TEEC_InitializeContext(NULL, &ctx);
	if (res != TEEC_SUCCESS) {
		fprintf(stderr, "TEEC_InitializeContext failed: 0x%x\n", res);
		return 1;
	}
	res = TEEC_OpenSession(&ctx, &sess, &uuid, TEEC_LOGIN_PUBLIC,
			       NULL, NULL, &origin);
	if (res != TEEC_SUCCESS) {
		fprintf(stderr, "TEEC_OpenSession failed: 0x%x origin 0x%x\n",
			res, origin);
		TEEC_FinalizeContext(&ctx);
		return 1;
	}
	printf("Opened session to custom TA %08x-...\n", uuid.timeLow);

	/* 1) INC: 41 -> 42 */
	memset(&op, 0, sizeof(op));
	op.paramTypes = TEEC_PARAM_TYPES(TEEC_VALUE_INOUT, TEEC_NONE,
					 TEEC_NONE, TEEC_NONE);
	op.params[0].value.a = 41;
	res = TEEC_InvokeCommand(&sess, TA_SELFTEST_CMD_INC, &op, &origin);
	check("INC 41->42", res == TEEC_SUCCESS && op.params[0].value.a == 42);

	/* 2) SUM: 40 + 2 -> 42 */
	memset(&op, 0, sizeof(op));
	op.paramTypes = TEEC_PARAM_TYPES(TEEC_VALUE_INPUT, TEEC_VALUE_OUTPUT,
					 TEEC_NONE, TEEC_NONE);
	op.params[0].value.a = 40;
	op.params[0].value.b = 2;
	res = TEEC_InvokeCommand(&sess, TA_SELFTEST_CMD_SUM, &op, &origin);
	check("SUM 40+2=42", res == TEEC_SUCCESS && op.params[1].value.a == 42);

	/* 3) SHA-256("abc") computed in the TEE, compared to the FIPS vector */
	{
		char in[] = "abc";
		uint8_t out[32] = {0};
		memset(&op, 0, sizeof(op));
		op.paramTypes = TEEC_PARAM_TYPES(TEEC_MEMREF_TEMP_INPUT,
						 TEEC_MEMREF_TEMP_OUTPUT,
						 TEEC_NONE, TEEC_NONE);
		op.params[0].tmpref.buffer = in;
		op.params[0].tmpref.size = 3; /* "abc" without NUL */
		op.params[1].tmpref.buffer = out;
		op.params[1].tmpref.size = sizeof(out);
		res = TEEC_InvokeCommand(&sess, TA_SELFTEST_CMD_SHA256, &op,
					 &origin);
		check("SHA256(\"abc\") in TEE",
		      res == TEEC_SUCCESS &&
		      op.params[1].tmpref.size == 32 &&
		      memcmp(out, sha256_abc, 32) == 0);
	}

	/* 4) TRNG: two draws must differ and not be all-zero */
	{
		uint8_t r1[16] = {0}, r2[16] = {0}, zero[16] = {0};
		memset(&op, 0, sizeof(op));
		op.paramTypes = TEEC_PARAM_TYPES(TEEC_MEMREF_TEMP_OUTPUT,
						 TEEC_NONE, TEEC_NONE, TEEC_NONE);
		op.params[0].tmpref.buffer = r1;
		op.params[0].tmpref.size = sizeof(r1);
		res = TEEC_InvokeCommand(&sess, TA_SELFTEST_CMD_RANDOM, &op,
					 &origin);
		TEEC_Result res2 = TEEC_SUCCESS;
		if (res == TEEC_SUCCESS) {
			memset(&op, 0, sizeof(op));
			op.paramTypes = TEEC_PARAM_TYPES(TEEC_MEMREF_TEMP_OUTPUT,
							 TEEC_NONE, TEEC_NONE,
							 TEEC_NONE);
			op.params[0].tmpref.buffer = r2;
			op.params[0].tmpref.size = sizeof(r2);
			res2 = TEEC_InvokeCommand(&sess, TA_SELFTEST_CMD_RANDOM,
						  &op, &origin);
		}
		check("TRNG (non-zero, differs)",
		      res == TEEC_SUCCESS && res2 == TEEC_SUCCESS &&
		      memcmp(r1, zero, 16) != 0 && memcmp(r1, r2, 16) != 0);
	}

	TEEC_CloseSession(&sess);
	TEEC_FinalizeContext(&ctx);

	printf("\n%s (%d failure%s)\n", failures ? "SELFTEST FAILED" :
	       "SELFTEST PASSED", failures, failures == 1 ? "" : "s");
	return failures ? 1 : 0;
}
