use "std/test" as test
use "std/crypto" as crypto

test.module("Crypto Module Tests")

test.describe("HMAC-SHA256", fun ()
    test.it("computes correct HMAC-SHA256", fun ()
        let result = crypto.hmac_sha256("Hello World", "secret")
        test.assert_eq(result, "82ce0d2f821fa0ce5447b21306f214c99240fecc6387779d7515148bbdd0c415", nil)
    end)

    test.it("handles empty message", fun ()
        let result = crypto.hmac_sha256("", "key")
        test.assert_eq(result, "5d5d139563c95b5967b9bd9a8c9b233a9dedb45072794cd232dc1b74832607d0", nil)
    end)

    test.it("handles empty key", fun ()
        let result = crypto.hmac_sha256("message", "")
        test.assert_eq(result, "eb08c1f56d5ddee07f7bdf80468083da06b64cf4fac64fe3a90883df5feacae4", nil)
    end)

    test.it("different keys produce different results", fun ()
        let hmac1 = crypto.hmac_sha256("test", "key1")
        let hmac2 = crypto.hmac_sha256("test", "key2")
        test.assert_neq(hmac1, hmac2, nil)
    end)

    test.it("different messages produce different results", fun ()
        let hmac1 = crypto.hmac_sha256("message1", "secret")
        let hmac2 = crypto.hmac_sha256("message2", "secret")
        test.assert_neq(hmac1, hmac2, nil)
    end)

    test.it("returns 64 hex characters", fun ()
        let result = crypto.hmac_sha256("test", "key")
        test.assert_eq(result.len(), 64, nil)
    end)
end)

test.describe("HMAC-SHA512", fun ()
    test.it("computes correct HMAC-SHA512", fun ()
        let result = crypto.hmac_sha512("Hello World", "secret")
        test.assert_eq(result, "6d1d186ec481f3e7d1f604e7a74081140a713a8d8bac568e257ed1af9598f64f27f1f4bdaf0edfa1d316a1a7740647db38e7de82e77942cb98c4a08a4d17e89f", nil)
    end)

    test.it("handles empty message", fun ()
        let result = crypto.hmac_sha512("", "key")
        test.assert_eq(result, "84fa5aa0279bbc473267d05a53ea03310a987cecc4c1535ff29b6d76b8f1444a728df3aadb89d4a9a6709e1998f373566e8f824a8ca93b1821f0b69bc2a2f65e", nil)
    end)

    test.it("handles empty key", fun ()
        let result = crypto.hmac_sha512("message", "")
        test.assert_eq(result, "08fce52f6395d59c2a3fb8abb281d74ad6f112b9a9c787bcea290d94dadbc82b2ca3e5e12bf2277c7fedbb0154d5493e41bb7459f63c8e39554ea3651b812492", nil)
    end)

    test.it("different keys produce different results", fun ()
        let hmac1 = crypto.hmac_sha512("test", "key1")
        let hmac2 = crypto.hmac_sha512("test", "key2")
        test.assert_neq(hmac1, hmac2, nil)
    end)

    test.it("different messages produce different results", fun ()
        let hmac1 = crypto.hmac_sha512("message1", "secret")
        let hmac2 = crypto.hmac_sha512("message2", "secret")
        test.assert_neq(hmac1, hmac2, nil)
    end)

    test.it("returns 128 hex characters", fun ()
        let result = crypto.hmac_sha512("test", "key")
        test.assert_eq(result.len(), 128, nil)
    end)
end)

test.describe("HMAC Properties", fun ()
    test.it("deterministic output", fun ()
        let hmac1 = crypto.hmac_sha256("consistent", "key")
        let hmac2 = crypto.hmac_sha256("consistent", "key")
        test.assert_eq(hmac1, hmac2, nil)
    end)

end)
