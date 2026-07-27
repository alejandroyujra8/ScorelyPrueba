import asyncio
import selectors


def crear_event_loop() -> asyncio.AbstractEventLoop:
    return asyncio.SelectorEventLoop(
        selectors.SelectSelector()
    )