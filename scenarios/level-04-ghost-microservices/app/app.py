"""Three-tier checkout microservices stand-in for Level 04.

A single stdlib-only Python image runs as `gateway`, `cart`, or `payment`
depending on the `SERVICE_ROLE` environment variable:
  gateway -> cart -> payment

When `SERVICE_ROLE=payment`:
- Standard health checks (`GET /healthz`) and non-coupon payment methods
  (`credit_card`, `debit_card`, `apple_pay`, `paypal`, `wallet`, `bank_transfer`)
  succeed with HTTP 200.
- On startup, emits structured production log traffic (5,000 lines in the broken state). When
  `COUPON_VALIDATOR_URL` is missing from the environment, intermittent
  `payment_method=coupon` transactions buried inside those 5,000 lines log an
  unhandled `NullPointerException` stack trace, and live `"coupon"` requests
  return HTTP 500 (cascading back through `cart` and `gateway`).
"""
import json
import os
import sys
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT = int(os.environ.get("PORT", "8080"))
SERVICE_ROLE = os.environ.get("SERVICE_ROLE", "gateway")
CART_SERVICE_URL = os.environ.get(
    "CART_SERVICE_URL",
    "http://cart.escape-level-04.svc.cluster.local:8080/cart/checkout",
)
PAYMENT_SERVICE_URL = os.environ.get(
    "PAYMENT_SERVICE_URL",
    "http://payment.escape-level-04.svc.cluster.local:8080/payment/process",
)

STANDARD_METHODS = (
    "credit_card",
    "debit_card",
    "apple_pay",
    "paypal",
    "wallet",
    "bank_transfer",
)


def format_npe_trace(tx_id, amount_cents):
    """Return a 5-line NullPointerException log entry for coupon checkouts."""
    return [
        (
            f"2026-10-24T11:14:08.312Z ERROR [payment-worker-2] PaymentProcessor "
            f"— Unhandled exception processing checkout tx_id={tx_id} "
            f"payment_method=coupon amount_cents={amount_cents}"
        ),
        (
            'java.lang.NullPointerException: Cannot invoke '
            '"CouponValidator.redeem(String, int)" because "this.couponValidator" '
            "is null (required env COUPON_VALIDATOR_URL is not set)"
        ),
        "\tat com.escaperoom.payment.CouponPaymentHandler.redeem(CouponPaymentHandler.java:74)",
        "\tat com.escaperoom.payment.PaymentProcessor.process(PaymentProcessor.java:112)",
        "\tat com.escaperoom.payment.CheckoutHttpHandler.doPost(CheckoutHttpHandler.java:68)",
    ]


def emit_startup_logs(role, coupon_validator_url):
    """Emit realistic startup log traffic (5,000 lines for a broken `payment`)."""
    if role == "gateway":
        lines = [
            "2026-10-24T11:00:00.010Z INFO [main] GatewayServer — Starting checkout API gateway on :8080",
        ]
        for i in range(1, 121):
            tx_id = f"tx-{1000 + i:06d}"
            if not coupon_validator_url and i in (35, 78, 104):
                lines.append(
                    f"2026-10-24T11:0{i // 20}:12.420Z ERROR [gateway-worker-1] CheckoutProxy "
                    f"— Upstream cart service ({CART_SERVICE_URL}) returned HTTP 500 for POST /checkout tx_id={tx_id}"
                )
            else:
                method = STANDARD_METHODS[i % len(STANDARD_METHODS)]
                lines.append(
                    f"2026-10-24T11:0{i // 20}:12.110Z INFO [gateway-worker-1] CheckoutProxy "
                    f"— Completed POST /checkout tx_id={tx_id} payment_method={method} status=200 latency_ms=18"
                )
        sys.stdout.write("\n".join(lines) + "\n")
        sys.stdout.flush()
        return

    if role == "cart":
        lines = [
            "2026-10-24T11:00:00.015Z INFO [main] CartServer — Starting cart service on :8080",
        ]
        for i in range(1, 121):
            tx_id = f"tx-{1000 + i:06d}"
            if not coupon_validator_url and i in (35, 78, 104):
                lines.append(
                    f"2026-10-24T11:0{i // 20}:12.419Z ERROR [cart-worker-2] CartCheckoutService "
                    f"— Upstream payment service ({PAYMENT_SERVICE_URL}) returned HTTP 500 for tx_id={tx_id}"
                )
            else:
                lines.append(
                    f"2026-10-24T11:0{i // 20}:12.105Z INFO [cart-worker-2] CartCheckoutService "
                    f"— Validated cart items and settled payment for tx_id={tx_id} status=200 latency_ms=15"
                )
        sys.stdout.write("\n".join(lines) + "\n")
        sys.stdout.flush()
        return

    # role == "payment": emit log traffic (5,000 lines when broken).
    # When broken, 3 intermittent coupon transactions (5 lines each = 15 lines)
    # are buried at indices 1250, 2750, and 4150 inside 4,985 INFO lines.
    coupon_state = "configured" if coupon_validator_url else "null"
    buffer = [
        f"2026-10-24T11:00:00.001Z INFO [main] PaymentServer — Starting payment service on :{PORT} "
        f"(currency={os.environ.get('PAYMENT_CURRENCY', 'USD')}, cardProcessor=configured, couponValidator={coupon_state})"
    ]

    error_indices = {1250, 2750, 4150}
    normal_target = 4985 if not coupon_validator_url else 4999

    for idx in range(1, normal_target):
        tx_id = f"tx-{idx:06d}"
        minute = (idx // 90) % 60
        second = idx % 60
        if not coupon_validator_url and idx in error_indices:
            buffer.extend(format_npe_trace(tx_id, 2500))
        if idx % 25 == 0:
            buffer.append(
                f"2026-10-24T11:{minute:02d}:{second:02d}.050Z INFO [payment-worker-1] HealthProbe "
                "— GET /healthz status=200 latency_ms=1"
            )
        elif idx % 40 == 0:
            buffer.append(
                f"2026-10-24T11:{minute:02d}:{second:02d}.090Z INFO [settlement-batch] LedgerSync "
                f"— Flushed 40 settled authorizations to ledger batch_id=batch-{idx // 40:03d}"
            )
        else:
            method = STANDARD_METHODS[idx % len(STANDARD_METHODS)]
            amount = 1500 + (idx % 17) * 250
            buffer.append(
                f"2026-10-24T11:{minute:02d}:{second:02d}.210Z INFO [payment-worker-{(idx % 4) + 1}] PaymentProcessor "
                f"— Authorized tx_id={tx_id} payment_method={method} amount_cents={amount} currency=USD status=200 latency_ms={8 + (idx % 9)}"
            )

        if len(buffer) >= 500:
            sys.stdout.write("\n".join(buffer) + "\n")
            buffer.clear()

    if buffer:
        sys.stdout.write("\n".join(buffer) + "\n")
    sys.stdout.flush()


def post_json(url, payload):
    """Send a JSON POST request and return (status_code, parsed_body)."""
    raw = json.dumps(payload, separators=(",", ":")).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=raw,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=4) as resp:
            body = resp.read().decode("utf-8")
            return resp.status, json.loads(body) if body else {}
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        try:
            parsed = json.loads(body) if body else {}
        except ValueError:
            parsed = {"raw": body}
        return exc.code, parsed
    except Exception as exc:  # noqa: BLE001
        return 502, {"status": "error", "message": str(exc)}


class MicroserviceHandler(BaseHTTPRequestHandler):
    role = "gateway"
    coupon_validator_url = None
    card_processor_url = None

    def send_json(self, status_code, payload):
        body = json.dumps(payload, separators=(",", ":")).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/healthz":
            self.send_json(200, {"status": "healthy", "service": self.role})
            return
        self.send_json(404, {"status": "error", "message": "not found"})

    def do_POST(self):
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length).decode("utf-8") if length > 0 else "{}"
        try:
            payload = json.loads(raw) if raw else {}
        except ValueError:
            self.send_json(400, {"status": "error", "message": "invalid JSON payload"})
            return

        tx_id = str(payload.get("tx_id", "tx-live"))
        payment_method = str(payload.get("payment_method", "credit_card"))
        try:
            amount_cents = int(payload.get("amount", 2500))
        except (TypeError, ValueError):
            self.send_json(400, {"status": "error", "message": "invalid amount"})
            return

        if self.role == "gateway":
            if self.path not in ("/checkout", "/api/checkout", "/"):
                self.send_json(404, {"status": "error", "message": "not found"})
                return
            status, upstream = post_json(CART_SERVICE_URL, payload)
            if status != 200:
                print(
                    f"2026-10-24T12:00:00.000Z ERROR [gateway-worker-1] CheckoutProxy "
                    f"— Upstream cart service ({CART_SERVICE_URL}) returned HTTP {status} for POST {self.path} tx_id={tx_id}",
                    flush=True,
                )
                self.send_json(
                    500,
                    {
                        "status": "error",
                        "service": "gateway",
                        "tx_id": tx_id,
                        "message": "Internal Server Error: upstream cart checkout failed",
                    },
                )
                return

            print(
                f"2026-10-24T12:00:00.000Z INFO [gateway-worker-1] CheckoutProxy "
                f"— Completed POST {self.path} tx_id={tx_id} payment_method={payment_method} status=200",
                flush=True,
            )
            self.send_json(
                200,
                {
                    "status": "completed",
                    "service": "gateway",
                    "cart": upstream.get("cart", "validated"),
                    "payment": upstream.get("payment", "approved"),
                    "payment_method": payment_method,
                    "tx_id": tx_id,
                },
            )
            return

        if self.role == "cart":
            if self.path not in ("/cart/checkout", "/checkout", "/"):
                self.send_json(404, {"status": "error", "message": "not found"})
                return
            status, upstream = post_json(PAYMENT_SERVICE_URL, payload)
            if status != 200:
                print(
                    f"2026-10-24T12:00:00.000Z ERROR [cart-worker-2] CartCheckoutService "
                    f"— Upstream payment service ({PAYMENT_SERVICE_URL}) returned HTTP {status} for tx_id={tx_id}",
                    flush=True,
                )
                self.send_json(
                    500,
                    {
                        "status": "error",
                        "service": "cart",
                        "tx_id": tx_id,
                        "message": "Upstream payment service returned HTTP 500",
                    },
                )
                return

            print(
                f"2026-10-24T12:00:00.000Z INFO [cart-worker-2] CartCheckoutService "
                f"— Validated cart items and settled payment for tx_id={tx_id} payment_method={payment_method} status=200",
                flush=True,
            )
            self.send_json(
                200,
                {
                    "status": "validated",
                    "service": "cart",
                    "cart": "validated",
                    "payment": upstream.get("status", "approved"),
                    "payment_method": payment_method,
                    "tx_id": tx_id,
                },
            )
            return

        # role == "payment"
        if self.path not in ("/payment/process", "/process", "/checkout", "/"):
            self.send_json(404, {"status": "error", "message": "not found"})
            return

        if payment_method == "coupon":
            if not self.coupon_validator_url:
                for line in format_npe_trace(tx_id, amount_cents):
                    print(line, flush=True)
                self.send_json(
                    500,
                    {
                        "status": "error",
                        "service": "payment",
                        "tx_id": tx_id,
                        "exception": "NullPointerException",
                    },
                )
                return

            print(
                f"2026-10-24T12:00:00.000Z INFO [payment-worker-2] PaymentProcessor "
                f"— Redeemed coupon and authorized tx_id={tx_id} payment_method=coupon amount_cents={amount_cents} status=200",
                flush=True,
            )
            self.send_json(
                200,
                {
                    "status": "approved",
                    "service": "payment",
                    "payment_method": "coupon",
                    "tx_id": tx_id,
                },
            )
            return

        if not self.card_processor_url:
            print(
                f"2026-10-24T12:00:00.000Z ERROR [payment-worker-1] PaymentProcessor "
                f"— Missing CARD_PROCESSOR_URL for tx_id={tx_id}",
                flush=True,
            )
            self.send_json(500, {"status": "error", "service": "payment"})
            return

        print(
            f"2026-10-24T12:00:00.000Z INFO [payment-worker-1] PaymentProcessor "
            f"— Authorized tx_id={tx_id} payment_method={payment_method} amount_cents={amount_cents} status=200",
            flush=True,
        )
        self.send_json(
            200,
            {
                "status": "approved",
                "service": "payment",
                "payment_method": payment_method,
                "tx_id": tx_id,
            },
        )

    def log_message(self, fmt, *args):
        # Suppress default BaseHTTPRequestHandler stderr lines so structured stdout logs stay clean
        return


def main():
    role = SERVICE_ROLE
    coupon_validator_url = os.environ.get("COUPON_VALIDATOR_URL")
    card_processor_url = os.environ.get(
        "CARD_PROCESSOR_URL",
        "http://card-gateway.fake-internal:8443/v2/charge",
    )

    MicroserviceHandler.role = role
    MicroserviceHandler.coupon_validator_url = coupon_validator_url
    MicroserviceHandler.card_processor_url = card_processor_url

    emit_startup_logs(role, coupon_validator_url)
    HTTPServer(("", PORT), MicroserviceHandler).serve_forever()


if __name__ == "__main__":
    main()
