// Types for the window.__guide API that ../guide-panel.js installs in the page.
export {};

declare global {
  interface GuideStep {
    step: number;
    total: number;
    title: string;
    html: string;
  }

  interface GuideEvent {
    type: "next" | "prev" | "message" | "close";
    text?: string;
    step: number | null;
    at: string;
  }

  interface Guide {
    connect(relayUrl: string): void;
    show(step: GuideStep): void;
    say(html: string): void;
    status(text: string): void;
    busy(isBusy: boolean): void;
    autoplay(seconds: number | boolean): void;
    waitForEvent(timeoutMs?: number): Promise<GuideEvent | null>;
    highlight(target: string | Element, label?: string): boolean;
    clearHighlights(): void;
    pointTo(target: string | Element): Promise<{ x: number; y: number; viewportWidth: number } | null>;
    find(text: string): Element | null;
  }

  interface Window {
    __guide: Guide;
  }
}
