import base64, time
import sys

if __name__ == "__main__":
    for src, dst in [("hello", "aGVsbG8="), ("world", "d29ybGQ=")]:
        encoded = base64.b64encode(src.encode()).decode()
        if encoded != dst:
            print("%s != %s" % (encoded, dst), file=sys.stderr)
            quit(1)
        decoded = base64.b64decode(dst).decode()
        if decoded != src:
            print("%s != %s" % (decoded, src), file=sys.stderr)
            quit(1)

    STR_SIZE = 131072
    TRIES = 8192

    str1 = b"a" * STR_SIZE
    str2 = base64.b64encode(str1)
    str3 = base64.b64decode(str2)

    t, s_encoded = time.time(), 0
    for _ in range(0, TRIES):
        s_encoded += len(base64.b64encode(str1))
    t_encoded = time.time() - t

    t, s_decoded = time.time(), 0
    for _ in range(0, TRIES):
        s_decoded += len(base64.b64decode(str2))
    t_decoded = time.time() - t

    print(
        "encode {0}... to {1}...: {2}, {3}".format(
            str1[:4], str2[:4], s_encoded, t_encoded
        )
    )
    print(
        "decode {0}... to {1}...: {2}, {3} ".format(
            str2[:4], str3[:4], s_decoded, t_decoded
        )
    )
