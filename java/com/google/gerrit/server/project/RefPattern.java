// Copyright (C) 2016 The Android Open Source Project
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

package com.google.gerrit.server.project;

import com.google.common.base.Throwables;
import com.google.common.cache.CacheBuilder;
import com.google.common.cache.CacheLoader;
import com.google.common.cache.LoadingCache;
import com.google.common.collect.ImmutableMap;
import com.google.common.flogger.FluentLogger;
import com.google.gerrit.common.data.AccessSection;
import com.google.gerrit.common.data.ParameterizedString;
import com.google.gerrit.exceptions.InvalidNameException;
import dk.brics.automaton.RegExp;
import java.util.Map;
import java.util.concurrent.ExecutionException;
import java.util.regex.Pattern;
import java.util.regex.PatternSyntaxException;
import org.eclipse.jgit.lib.Repository;

public class RefPattern {
  private static final FluentLogger logger = FluentLogger.forEnclosingClass();
  public static final String USERID_SHARDED = "shardeduserid";
  public static final String USERNAME = "username";

  private static final LoadingCache<String, String> exampleCache =
      CacheBuilder.newBuilder()
          .maximumSize(4000)
          .build(
              new CacheLoader<String, String>() {
                @Override
                public String load(String refPattern) {
				  logger.atInfo().log("exampleCache CacheLoader load refPattern:%s", refPattern);
                  return example(refPattern);
                }
              });

  public static String shortestExample(String refPattern) {
    logger.atInfo().log("shortestExampletest test isRE refPattern:%s", refPattern);
    if (isRE(refPattern)) {
      try {
        String toRet = exampleCache.get(refPattern);
        logger.atInfo().log("validate shortestExampletest toRet:" + toRet);
        return toRet;
      } catch (ExecutionException e) {
        Throwables.throwIfUnchecked(e.getCause());
        throw new RuntimeException(e);
      }
    } else if (refPattern.endsWith("/*")) {
      return refPattern.substring(0, refPattern.length() - 1) + '1';
    } else {
      return refPattern;
    }
  }

  static String example(String refPattern) {
    // Since Brics will substitute dot [.] with \0 when generating
    // shortest example, any usage of dot will fail in
    // Repository.isValidRefName() if not combined with star [*].
    // To get around this, we substitute the \0 with an arbitrary
    // accepted character.
    logger.atInfo().log("example getShortestExample:%s", refPattern);
    return toRegExp(refPattern).toAutomaton().getShortestExample(true).replace('\0', '-');
  }

  public static boolean isRE(String refPattern) {
    return refPattern.startsWith(AccessSection.REGEX_PREFIX);
  }

  public static RegExp toRegExp(String refPattern) {
    logger.atInfo().log("toRegExp ENTRY refPattern:%s", refPattern);
    /*
    if (isRE(refPattern)) {
      refPattern = refPattern.substring(1);
    }
    */
    ParameterizedString template = new ParameterizedString(refPattern);
    Map<String, String> params =
        ImmutableMap.of(
            RefPattern.USERID_SHARDED, "\\$\\{" + RefPattern.USERID_SHARDED + "\\}",
            RefPattern.USERNAME, "\\$\\{" + RefPattern.USERNAME + "\\}");
    String toto = template.replace(params);
    logger.atInfo().log("toRegExp EXIT new RegExp %s", toto);
    return new RegExp(toto, RegExp.NONE);
  }

  public static void validate(String refPattern) throws InvalidNameException {
    logger.atInfo().log("validate ENTRY refPattern:%s", refPattern);
    if (refPattern.startsWith(AccessSection.REGEX_PREFIX)) {
	  logger.atInfo().log("validate before shortestExample refPattern:%s", refPattern);
      String shortestEx = shortestExample(refPattern);
      logger.atInfo().log("validate after shortestExample shortestEx:%s", shortestEx);
      if (!Repository.isValidRefName(shortestEx)) {
        logger.atInfo().log("validate InvalidNameException1");
        throw new InvalidNameException(refPattern);
      }
    } else if (refPattern.equals(AccessSection.ALL)) {
      // This is a special case we have to allow, it fails below.
    } else if (refPattern.endsWith("/*")) {
      String prefix = refPattern.substring(0, refPattern.length() - 2);
      if (!Repository.isValidRefName(prefix)) {
        logger.atInfo().log("validate InvalidNameException2");
        throw new InvalidNameException(refPattern);
      }
    } else if (!Repository.isValidRefName(refPattern)) {
      logger.atInfo().log("validate InvalidNameException3");
      throw new InvalidNameException(refPattern);
    }
    validateRegExp(refPattern);
  }

  public static void validateRegExp(String refPattern) throws InvalidNameException {
    try {
      logger.atInfo().log("validateRegExp:" + refPattern);
      refPattern = refPattern.replace("${" + USERID_SHARDED + "}", "");
      refPattern = refPattern.replace("${" + USERNAME + "}", "");
      Pattern.compile(refPattern);
    } catch (PatternSyntaxException e) {
      logger.atInfo().log("validate InvalidNameException4");
      throw new InvalidNameException(refPattern + " " + e.getMessage());
    }
  }
}
