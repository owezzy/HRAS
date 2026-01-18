"use client";

import Avatar from "@mui/material/Avatar";
import Paper from "@mui/material/Paper";
import Typography from "@mui/material/Typography";
import FuseSvgIcon from "@fuse/core/FuseSvgIcon";
import ReactMarkdown from "react-markdown";
import remarkGfm from "remark-gfm";
import rehypeRaw from "rehype-raw";
import type { ChatSource, ChatMessage as ChatMessageType } from "../types";
import SourcesList from "./SourcesList";

interface ChatMessageProps {
  message: ChatMessageType;
  sources?: ChatSource[];
}

function ChatMessage({ message, sources }: ChatMessageProps) {
  const isUser = message.role === "user";

  return (
    <div className={`flex gap-3 ${isUser ? "flex-row-reverse" : "flex-row"}`}>
      <Avatar className={`h-8 w-8 ${isUser ? "bg-[#0072BC]" : "bg-gray-600"}`}>
        {isUser ? (
          <FuseSvgIcon size={18} className="text-white">
            heroicons-outline:user
          </FuseSvgIcon>
        ) : (
          <FuseSvgIcon size={18} className="text-white">
            heroicons-outline:cpu-chip
          </FuseSvgIcon>
        )}
      </Avatar>
      <div
        className={`flex max-w-[85%] flex-col ${isUser ? "items-end" : "items-start"}`}
      >
        <Paper
          className={`rounded-lg p-4 ${
            isUser
              ? "rounded-br-none bg-[#0072BC] text-white"
              : "rounded-bl-none bg-gray-100 text-gray-900"
          }`}
          elevation={0}
        >
          {isUser ? (
            <Typography variant="body1" className="whitespace-pre-wrap">
              {message.content}
            </Typography>
          ) : (
            <div className="prose prose-sm prose-headings:mb-2 prose-headings:mt-3 prose-headings:font-semibold prose-p:my-1 prose-ul:my-1 prose-ol:my-1 prose-li:my-0 prose-pre:bg-gray-800 prose-pre:text-gray-100 prose-code:rounded prose-code:bg-gray-200 prose-code:px-1 prose-code:py-0.5 prose-code:text-gray-800 prose-code:before:content-none prose-code:after:content-none prose-table:border prose-table:border-gray-300 prose-th:border prose-th:border-gray-300 prose-th:bg-gray-50 prose-th:font-semibold prose-th:px-3 prose-th:py-2 prose-th:text-left prose-td:border prose-td:border-gray-300 prose-td:px-3 prose-td:py-2 prose-blockquote:border-l-4 prose-blockquote:border-[#0072BC] prose-blockquote:pl-4 prose-hr:border-gray-300 max-w-none overflow-x-auto">
              <ReactMarkdown
                remarkPlugins={[remarkGfm]}
                rehypePlugins={[rehypeRaw]}
                components={{
                  table: ({ children }) => (
                    <div className="overflow-x-auto my-4">
                      <table className="min-w-full border-collapse border border-gray-300 text-sm">
                        {children}
                      </table>
                    </div>
                  ),
                  thead: ({ children }) => (
                    <thead className="bg-gray-50">{children}</thead>
                  ),
                  th: ({ children }) => (
                    <th className="border border-gray-300 px-3 py-2 text-left font-semibold text-gray-900 bg-gray-50">
                      {children}
                    </th>
                  ),
                  td: ({ children }) => (
                    <td className="border border-gray-300 px-3 py-2 text-gray-700">
                      {children}
                    </td>
                  ),
                  blockquote: ({ children }) => (
                    <blockquote className="border-l-4 border-[#0072BC] pl-4 py-1 my-3 text-gray-600 italic bg-blue-50">
                      {children}
                    </blockquote>
                  ),
                  code: ({ className, children, ...props }) => {
                    const match = /language-(\w+)/.exec(className || "");
                    return (
                      <code
                        className={`${
                          match
                            ? "block bg-gray-800 text-gray-100 p-3 rounded-md overflow-x-auto text-sm"
                            : "inline bg-gray-200 text-gray-800 px-1 py-0.5 rounded text-sm"
                        }`}
                        {...props}
                      >
                        {children}
                      </code>
                    );
                  },
                  hr: () => <hr className="my-4 border-gray-300" />,
                  a: ({ href, children }) => (
                    <a
                      href={href}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="text-[#0072BC] underline hover:text-blue-800"
                    >
                      {children}
                    </a>
                  ),
                  strong: ({ children }) => (
                    <strong className="font-semibold text-gray-900">
                      {children}
                    </strong>
                  ),
                  em: ({ children }) => (
                    <em className="italic text-gray-700">{children}</em>
                  ),
                }}
              >
                {message.content}
              </ReactMarkdown>
            </div>
          )}
        </Paper>
        {!isUser && sources && sources.length > 0 && (
          <SourcesList sources={sources} />
        )}
      </div>
    </div>
  );
}

export default ChatMessage;
