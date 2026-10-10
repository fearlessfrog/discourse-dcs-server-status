import getURL from "discourse/lib/get-url";
import DiscourseURL from "discourse/lib/url";

export function headerDestination(url) {
  const destination = url?.trim();
  return destination ? getURL(destination) : null;
}

export function followHeaderDestination(event, destination) {
  if (
    event.button === 0 &&
    !event.ctrlKey &&
    !event.metaKey &&
    !event.shiftKey &&
    !event.altKey &&
    DiscourseURL.isInternal(destination)
  ) {
    event.preventDefault();
    DiscourseURL.routeTo(destination);
  }
}
