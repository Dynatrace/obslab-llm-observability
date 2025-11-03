package com.dynatrace.todoapp;

import org.slf4j.MDC;
import org.springframework.stereotype.Component;

import javax.servlet.*;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Random;
import java.util.UUID;

@Component
public class MdcLogEnhancerFilter implements Filter {
    private static final ArrayList<String> userIdsPool = new ArrayList<String>(){{
        add(generateUserID());
        add(generateUserID());
        add(generateUserID());
    }};
    private static final ArrayList<String> accountIdsPool = new ArrayList<String>(){{
        add(UUID.randomUUID().toString());
        add(UUID.randomUUID().toString());
        add(UUID.randomUUID().toString());
    }};

    @Override
    public void destroy() { }

    @Override
    public void init(FilterConfig filterConfig) throws ServletException { }

    @Override
    public void doFilter(ServletRequest servletRequest, ServletResponse servletResponse, FilterChain filterChain) throws IOException, ServletException
    {
        Random rand = new Random();
        MDC.put("requestId", UUID.randomUUID().toString());
        MDC.put("userId", userIdsPool.get(rand.nextInt(userIdsPool.size())));
        MDC.put("accountId", accountIdsPool.get(rand.nextInt(accountIdsPool.size())));

        MDC.put("remoteHost", servletRequest.getRemoteHost());
        MDC.put("localAddress", servletRequest.getLocalAddr());
        MDC.put("name", servletRequest.getLocalName());
        MDC.put("port", String.valueOf(servletRequest.getLocalPort()));
        MDC.put("encoding", servletRequest.getCharacterEncoding());

        filterChain.doFilter(servletRequest, servletResponse);
    }

    private static String generateUserID() {
        return UUID.randomUUID().toString().replace("-", "").substring(0, 8);
    }
}
